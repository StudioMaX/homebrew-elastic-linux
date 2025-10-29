class LogstashOss < Formula
  desc "Tool for managing events and logs"
  homepage "https://www.elastic.co/products/logstash"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/logstash/logstash-oss-7.17.4-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "655ab873e16257827f884f67b66d62c4da40a895d06206faa435615ad0a56796"
  else
    url "https://artifacts.elastic.co/downloads/logstash/logstash-oss-7.17.29-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "c9f4b8244f806ef23a05df2677e9c5916ea963b221d9661c50cb7277ae0d092f"
  end

  livecheck do
    url "https://me0ej585.api.sanity.io/v2022-03-25/data/query/production?query=*%5B_type+%3D%3D+%22product_versions%22+%26%26+references%28*%5B_type%3D%3D%22product_names%22+%26%26+lower%28title%29+%3D%3D+%22Logstash+OSS%22%5D._id%29%5D%7B%0A+version_number%2C%0A+%27v%27%3A+string%3A%3Asplit%28version_number%2C+%27.%27%29%0A+%7D+%7C+order%28%0A+length%28v%5B0%5D%29+desc%2C+v%5B0%5D+desc%2C%0A+length%28v%5B1%5D%29+desc%2C+v%5B1%5D+desc%2C%0A+length%28v%5B2%5D%29+desc%2C+v%5B2%5D+desc%2C%0A+%29&returnQuery=false"
    regex(/"version_number":"(#{Regexp.escape(version.major)}(?:\.\d+\.\d+)*)/i)
  end

  conflicts_with "logstash"
  conflicts_with "logstash-full"

  def install
    inreplace "bin/logstash",
              %r{^\. "\$\(cd `dirname \${SOURCEPATH}`/\.\.; pwd\)/bin/logstash\.lib\.sh"},
              ". #{libexec}/bin/logstash.lib.sh"
    inreplace "bin/logstash-plugin",
              %r{^\. "\$\(cd `dirname \$0`/\.\.; pwd\)/bin/logstash\.lib\.sh"},
              ". #{libexec}/bin/logstash.lib.sh"
    inreplace "bin/logstash.lib.sh",
              /^LOGSTASH_HOME=.*$/,
              "LOGSTASH_HOME=#{libexec}"

    libexec.install Dir["*"]

    # Move config files into etc
    (etc/"logstash").install Dir[libexec/"config/*"]
    rm_r(libexec/"config")

    bin.install libexec/"bin/logstash", libexec/"bin/logstash-plugin"
    bin.env_script_all_files(libexec/"bin", {})
    if OS.mac?
      system "find", "#{libexec}/jdk.app/Contents/Home/bin", "-type", "f",
              "-exec", "codesign", "-f", "-s", "-", "{}", ";"
    end
  end

  def post_install
    # Make sure runtime directories exist
    ln_s etc/"logstash", libexec/"config"
  end

  def caveats
    <<~EOS
      Please read the getting started guide located at:
        https://www.elastic.co/guide/en/logstash/current/getting-started-with-logstash.html
    EOS
  end

  service do
    run [opt_bin/"logstash"]
    working_dir var
    log_path var/"log/logstash.log"
    error_log_path var/"log/logstash.log"
  end

  test do
    # workaround https://github.com/elastic/logstash/issues/6378
    (testpath/"config").mkpath
    ["jvm.options", "log4j2.properties", "startup.options"].each do |f|
      cp prefix/"libexec/config/#{f}", testpath/"config"
    end
    (testpath/"config/logstash.yml").write <<~EOS
      path.queue: #{testpath}/queue
    EOS
    (testpath/"data").mkpath
    (testpath/"logs").mkpath
    (testpath/"queue").mkpath

    data = "--path.data=#{testpath}/data"
    logs = "--path.logs=#{testpath}/logs"
    settings = "--path.settings=#{testpath}/config"

    output = pipe_output("#{bin}/logstash -e '' #{data} #{logs} #{settings} --log.level=fatal", "hello world\n")
    assert_match "hello world", output
  end
end
