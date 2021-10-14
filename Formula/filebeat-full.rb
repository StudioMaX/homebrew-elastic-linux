class FilebeatFull < Formula
  desc "File harvester to ship log files to Elasticsearch or Logstash"
  homepage "https://www.elastic.co/products/beats/filebeat"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.15.1-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "94112d02fcf6a63cbdbb6bbaeee999ef6c5ee387ad1e39e32c15f8bbc996dc95"
  else
    url "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.14.1-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "bdc52591a1816bfff02a0cf6e31f4a78c74886ccdd3892daecc42d096c0d2f3f"
  end
  version "7.15.1"

  bottle :unneeded

  conflicts_with "filebeat"
  conflicts_with "filebeat-oss"

  def install
    ["fields.yml", "ingest", "kibana", "module"].each { |d| libexec.install d if File.exist?(d) }
    (libexec/"bin").install "filebeat"
    (etc/"filebeat").install "filebeat.yml"
    (etc/"filebeat").install "modules.d" if File.exist?("modules.d")

    (bin/"filebeat").write <<~EOS
      #!/bin/sh
      exec #{libexec}/bin/filebeat \
        --path.config #{etc}/filebeat \
        --path.data #{var}/lib/filebeat \
        --path.home #{libexec} \
        --path.logs #{var}/log/filebeat \
        "$@"
    EOS
  end

  plist_options :manual => "filebeat"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>Program</key>
        <string>#{opt_bin}/filebeat</string>
        <key>RunAtLoad</key>
        <true/>
      </dict>
    </plist>
  EOS
  end

  test do
    log_file = testpath/"test.log"
    touch log_file

    (testpath/"filebeat.yml").write <<~EOS
      filebeat:
        inputs:
          -
            paths:
              - #{log_file}
            scan_frequency: 0.1s
      output:
        file:
          path: #{testpath}
    EOS
    chmod "go-w", testpath/"filebeat.yml" unless OS.mac?

    (testpath/"log").mkpath
    (testpath/"data").mkpath

    filebeat_pid = fork do
      exec bin/"filebeat", "-c", testpath/"filebeat.yml", "-path.config",
                             testpath/"filebeat", "-path.home=#{testpath}",
                             "-path.logs", testpath/"log", "-path.data", testpath
    end
    begin
      sleep 1
      log_file.append_lines "foo bar baz"
      sleep 5

      assert_predicate testpath/"filebeat", :exist?
    ensure
      Process.kill("TERM", filebeat_pid)
    end
  end
end
