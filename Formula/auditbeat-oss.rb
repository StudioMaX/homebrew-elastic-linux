class AuditbeatOss < Formula
  desc "Lightweight Shipper for Audit Data"
  homepage "https://www.elastic.co/products/beats/auditbeat"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/beats/auditbeat/auditbeat-oss-7.16.0-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "ce89208cd4598f3c6f1af802484c09cdfe3669b7ce2051075897a3221a56531d"
  else
    url "https://artifacts.elastic.co/downloads/beats/auditbeat/auditbeat-oss-7.16.0-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "73dfc91604166131ebe04dcb17cf1e4e5534511e0230d5c4d0186e5b80322f6e"
  end
  version "7.16.0"

  conflicts_with "auditbeat"
  conflicts_with "auditbeat-full"

  def install
    ["fields.yml", "ingest", "kibana", "module"].each { |d| libexec.install d if File.exist?(d) }
    (libexec/"bin").install "auditbeat"
    (etc/"auditbeat").install "auditbeat.yml"
    (etc/"auditbeat").install "modules.d" if File.exist?("modules.d")

    (bin/"auditbeat").write <<~EOS
      #!/bin/sh
      exec #{libexec}/bin/auditbeat \
        --path.config #{etc}/auditbeat \
        --path.data #{var}/lib/auditbeat \
        --path.home #{libexec} \
        --path.logs #{var}/log/auditbeat \
        "$@"
    EOS
  end

  def post_install
    (var/"lib/auditbeat").mkpath
    (var/"log/auditbeat").mkpath
  end

  plist_options :manual => "auditbeat"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>Program</key>
        <string>#{opt_bin}/auditbeat</string>
        <key>RunAtLoad</key>
        <true/>
      </dict>
    </plist>
  EOS
  end

  test do
    (testpath/"files").mkpath
    (testpath/"config/auditbeat.yml").write <<~EOS
      auditbeat.modules:
      - module: file_integrity
        paths:
          - #{testpath}/files
      output.file:
        path: "#{testpath}/auditbeat"
        filename: auditbeat
    EOS
    chmod "go-w", testpath/"config/auditbeat.yml" unless OS.mac?
    pid = fork do
      exec "#{bin}/auditbeat", "-path.config", testpath/"config", "-path.data", testpath/"data"
    end
    sleep 20

    begin
      touch testpath/"files/touch"
      sleep 30
      s = IO.readlines(testpath/"auditbeat/auditbeat").last(1)[0]
      assert_match "\"action\":\[\"created\"\]", s
      realdirpath = File.realdirpath(testpath)
      assert_match "\"path\":\"#{realdirpath}/files/touch\"", s
    ensure
      Process.kill "SIGINT", pid
      Process.wait pid
    end
  end
end
