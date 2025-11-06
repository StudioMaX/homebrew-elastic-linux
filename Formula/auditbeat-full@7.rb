class AuditbeatFullAT7 < Formula
  desc "Lightweight Shipper for Audit Data"
  homepage "https://www.elastic.co/products/beats/auditbeat"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/beats/auditbeat/auditbeat-7.17.4-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "ef842a52a573ed658e8109410570f651e9208f2156008afbcf253c6daf35aee5"
  else
    url "https://artifacts.elastic.co/downloads/beats/auditbeat/auditbeat-7.17.29-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "2c9c42a21381954d0224dfd510df85b41de873e7f5020599b43272ea93212940"
  end

  livecheck do
    url "https://me0ej585.api.sanity.io/v2022-03-25/data/query/production?query=*%5B_type+%3D%3D+%22product_versions%22+%26%26+references%28*%5B_type%3D%3D%22product_names%22+%26%26+lower%28title%29+%3D%3D+%22Auditbeat%22%5D._id%29%5D%7B%0A+version_number%2C%0A+%27v%27%3A+string%3A%3Asplit%28version_number%2C+%27.%27%29%0A+%7D+%7C+order%28%0A+length%28v%5B0%5D%29+desc%2C+v%5B0%5D+desc%2C%0A+length%28v%5B1%5D%29+desc%2C+v%5B1%5D+desc%2C%0A+length%28v%5B2%5D%29+desc%2C+v%5B2%5D+desc%2C%0A+%29&returnQuery=false"
    regex(/"version_number":"(#{Regexp.escape(version.major)}(?:\.\d+\.\d+)*)/i)
  end

  keg_only :versioned_formula

  deprecate! date: "2026-01-15", because: :unsupported

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
