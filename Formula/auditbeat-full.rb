class AuditbeatFull < Formula
  desc "Lightweight Shipper for Audit Data"
  homepage "https://www.elastic.co/products/beats/auditbeat"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/beats/auditbeat/auditbeat-7.17.4-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "ef842a52a573ed658e8109410570f651e9208f2156008afbcf253c6daf35aee5"
  else
    url "https://artifacts.elastic.co/downloads/beats/auditbeat/auditbeat-7.17.28-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "41b7be89cc09ec465f8db21491ea040eb0bb7ec1adca421511c762d123865994"
  end

  conflicts_with "auditbeat"
  conflicts_with "auditbeat-oss"

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

  service do
    run opt_bin/"auditbeat"
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
      s = File.readlines(testpath/"auditbeat/auditbeat").last(1)[0]
      assert_match "\"action\":[\"created\"]", s
      realdirpath = File.realdirpath(testpath)
      assert_match "\"path\":\"#{realdirpath}/files/touch\"", s
    ensure
      Process.kill "SIGINT", pid
      Process.wait pid
    end
  end
end
