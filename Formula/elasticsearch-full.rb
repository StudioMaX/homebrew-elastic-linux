class ElasticsearchFull < Formula
  desc "Distributed search & analytics engine"
  homepage "https://www.elastic.co/products/elasticsearch"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.17.4-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "6d2343171a0d384910312220aae3512f45e3d3d900557b736c139b8363a008e4"
  else
    url "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.17.28-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "d72adef80b899eb624f6e14aa3b0d8c2ed6597e5fe328bbb1ed9de2c3c14ef28"
  end

  def cluster_name
    "elasticsearch_#{ENV["USER"]}"
  end

  def install
    # Install everything else into package directory
    libexec.install "bin", "config", "lib", "modules"
    if OS.mac?
      libexec.install "jdk.app"
    else
      libexec.install "jdk"
    end

    inreplace libexec/"bin/elasticsearch-env",
              "if [ -z \"$ES_PATH_CONF\" ]; then ES_PATH_CONF=\"$ES_HOME\"/config; fi",
              "if [ -z \"$ES_PATH_CONF\" ]; then ES_PATH_CONF=\"#{etc}/elasticsearch\"; fi"

    # Set up Elasticsearch for local development:
    inreplace "#{libexec}/config/elasticsearch.yml" do |s|
      # 1. Give the cluster a unique name
      s.gsub!(/#\s*cluster\.name: .*/, "cluster.name: #{cluster_name}")

      # 2. Configure paths
      s.sub!(/^#\s*path\.data:.+$/, "path.data: #{var}/lib/elasticsearch/")
      s.sub!(/^#\s*path\.logs:.+$/, "path.logs: #{var}/log/elasticsearch/")
    end

    inreplace "#{libexec}/config/jvm.options", %r{logs/gc.log}, "#{var}/log/elasticsearch/gc.log"

    # Move config files into etc
    (etc/"elasticsearch").install Dir[libexec/"config/*"]
    rm_r(libexec/"config")

    Dir.foreach(libexec/"bin") do |f|
      next if f == "." || f == ".." || !File.extname(f).empty?

      bin.install libexec/"bin"/f
    end
    bin.env_script_all_files(libexec/"bin", {})

    if OS.mac?
      system "codesign", "-f", "-s", "-",
              "#{libexec}/modules/x-pack-ml/platform/darwin-x86_64/controller.app",
              "--deep"
      system "find", "#{libexec}/jdk.app/Contents/Home/bin", "-type", "f",
              "-exec", "codesign", "-f", "-s", "-", "{}", ";"
    end
  end

  def post_install
    # Make sure runtime directories exist
    (var/"lib/elasticsearch/#{cluster_name}").mkpath
    (var/"log/elasticsearch").mkpath
    ln_s etc/"elasticsearch", libexec/"config"
    (var/"elasticsearch/plugins").mkpath
    ln_s var/"elasticsearch/plugins", libexec/"plugins"
  end

  def caveats
    <<~EOS
      Data:    #{var}/lib/elasticsearch/#{cluster_name}/
      Logs:    #{var}/log/elasticsearch/#{cluster_name}.log
      Plugins: #{var}/elasticsearch/plugins/
      Config:  #{etc}/elasticsearch/
    EOS
  end

  service do
    run [opt_bin/"elasticsearch"]
    working_dir var
    log_path var/"log/elasticsearch.log"
    error_log_path var/"log/elasticsearch.log"
  end

  test do
    require "socket"

    server = TCPServer.new(0)
    port = server.addr[1]
    server.close

    mkdir testpath/"config"
    cp etc/"elasticsearch/jvm.options", testpath/"config"
    cp etc/"elasticsearch/log4j2.properties", testpath/"config"
    touch testpath/"config/elasticsearch.yml"

    ENV["ES_PATH_CONF"] = testpath/"config"

    system "#{bin}/elasticsearch-plugin", "list"

    pid = testpath/"pid"
    begin
      system "#{bin}/elasticsearch", "-d", "-p", pid, "-Expack.security.enabled=false",
              "-Epath.data=#{testpath}/data", "-Epath.logs=#{testpath}/logs",
              "-Enode.name=test-cli", "-Ehttp.port=#{port}"
      sleep 30
      system "curl", "-XGET", "localhost:#{port}/"
      output = shell_output("curl -s -XGET localhost:#{port}/_cat/nodes")
      assert_match "test-cli", output
    ensure
      Process.kill(9, pid.read.to_i)
    end

    server = TCPServer.new(0)
    port = server.addr[1]
    server.close

    rm testpath/"config/elasticsearch.yml"
    (testpath/"config/elasticsearch.yml").write <<~EOS
      path.data: #{testpath}/data
      path.logs: #{testpath}/logs
      node.name: test-es-path-conf
      http.port: #{port}
    EOS

    pid = testpath/"pid"
    begin
      system "#{bin}/elasticsearch", "-d", "-p", pid, "-Expack.security.enabled=false"
      sleep 30
      system "curl", "-XGET", "localhost:#{port}/"
      output = shell_output("curl -s -XGET localhost:#{port}/_cat/nodes")
      assert_match "test-es-path-conf", output
    ensure
      Process.kill(9, pid.read.to_i)
    end
  end
end
