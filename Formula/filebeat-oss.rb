class FilebeatOss < Formula
  desc "File harvester to ship log files to Elasticsearch or Logstash"
  homepage "https://www.elastic.co/products/beats/filebeat"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-oss-7.16.2-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "9f8a2dd98eb1b465a7e80ca16a40a845710d6d16132caf8636a2ab47362cb410"
  else
    url "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-oss-7.16.2-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "5d38926c3fcda3f8b212943d2dea80950bacf809bf514c5506cc784547b84fed"
  end
  version "7.16.2"

  conflicts_with "filebeat"
  conflicts_with "filebeat-full"

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
