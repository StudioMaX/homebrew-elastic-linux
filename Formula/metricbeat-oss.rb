class MetricbeatOss < Formula
  desc "Collect metrics from your systems and services"
  homepage "https://www.elastic.co/products/beats/metricbeat"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-oss-7.17.2-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "0d6908280c606bb61efeb1729de3bde18e06429dd51718363bdd9dd477829055"
  else
    url "https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-oss-7.17.2-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "3918f2bbc196e811c337bba36ca99725d6f9d68a68d8a71fe9dbd4b1448bb006"
  end
  version "7.17.2"

  conflicts_with "metricbeat"
  conflicts_with "metricbeat-full"

  def install
    ["fields.yml", "ingest", "kibana", "module"].each { |d| libexec.install d if File.exist?(d) }
    (libexec/"bin").install "metricbeat"
    (etc/"metricbeat").install "metricbeat.yml"
    (etc/"metricbeat").install "modules.d" if File.exist?("modules.d")

    (bin/"metricbeat").write <<~EOS
      #!/bin/sh
      exec #{libexec}/bin/metricbeat \
        --path.config #{etc}/metricbeat \
        --path.data #{var}/lib/metricbeat \
        --path.home #{libexec} \
        --path.logs #{var}/log/metricbeat \
        "$@"
    EOS
  end

  plist_options :manual => "metricbeat"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>Program</key>
        <string>#{opt_bin}/metricbeat</string>
        <key>RunAtLoad</key>
        <true/>
      </dict>
    </plist>
  EOS
  end

  test do
    (testpath/"config/metricbeat.yml").write <<~EOS
      metricbeat.modules:
      - module: system
        metricsets: ["load"]
        period: 1s
      output.file:
        enabled: true
        path: #{testpath}/data
        filename: metricbeat
    EOS
    chmod "go-w", testpath/"config/metricbeat.yml" unless OS.mac?

    (testpath/"logs").mkpath
    (testpath/"data").mkpath

    pid = fork do
      exec bin/"metricbeat", "-path.config", testpath/"config", "-path.data",
                             testpath/"data"
    end

    begin
      sleep 30
      assert_predicate testpath/"data/metricbeat", :exist?
    ensure
      Process.kill "SIGINT", pid
      Process.wait pid
    end
  end
end
