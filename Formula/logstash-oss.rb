class LogstashOss < Formula
  desc "Tool for managing events and logs"
  homepage "https://www.elastic.co/products/logstash"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/logstash/logstash-oss-7.16.3-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "8392257298a06d20ae32ee4d6c83d2663a12447857ce8733a6bd237da3f4cb7c"
  else
    url "https://artifacts.elastic.co/downloads/logstash/logstash-oss-7.16.3-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "d32c0a00466f24d91417fdcba03fa683546d4833559f6afc24260a6549d7152f"
  end
  version "7.16.3"

  conflicts_with "logstash"
  conflicts_with "logstash-full"

  def install
    inreplace "bin/logstash",
              %r{^\. "\$\(cd `dirname \${SOURCEPATH}`\/\.\.; pwd\)\/bin\/logstash\.lib\.sh\"},
              ". #{libexec}/bin/logstash.lib.sh"
    inreplace "bin/logstash-plugin",
              %r{^\. "\$\(cd `dirname \$0`\/\.\.; pwd\)\/bin\/logstash\.lib\.sh\"},
              ". #{libexec}/bin/logstash.lib.sh"
    inreplace "bin/logstash.lib.sh",
              /^LOGSTASH_HOME=.*$/,
              "LOGSTASH_HOME=#{libexec}"

    libexec.install Dir["*"]

    # Move config files into etc
    (etc/"logstash").install Dir[libexec/"config/*"]
    (libexec/"config").rmtree

    bin.install libexec/"bin/logstash", libexec/"bin/logstash-plugin"
    bin.env_script_all_files(libexec/"bin", {})
    system "find", "#{libexec}/jdk.app/Contents/Home/bin", "-type", "f", "-exec", "codesign", "-f", "-s", "-", "{}", ";" if OS.mac?
  end

  def post_install
    # Make sure runtime directories exist
    ln_s etc/"logstash", libexec/"config"
  end

  def caveats; <<~EOS
    Please read the getting started guide located at:
      https://www.elastic.co/guide/en/logstash/current/getting-started-with-logstash.html
  EOS
  end

  plist_options :manual => "logstash"

  def plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>KeepAlive</key>
          <false/>
          <key>Label</key>
          <string>#{plist_name}</string>
          <key>ProgramArguments</key>
          <array>
            <string>#{opt_bin}/logstash</string>
          </array>
          <key>EnvironmentVariables</key>
          <dict>
          </dict>
          <key>RunAtLoad</key>
          <true/>
          <key>WorkingDirectory</key>
          <string>#{var}</string>
          <key>StandardErrorPath</key>
          <string>#{var}/log/logstash.log</string>
          <key>StandardOutPath</key>
          <string>#{var}/log/logstash.log</string>
        </dict>
      </plist>
    EOS
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
