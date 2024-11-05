class MetricbeatOss < Formula
  desc "Collect metrics from your systems and services"
  homepage "https://www.elastic.co/products/beats/metricbeat"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-oss-7.17.4-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "2fa07950504f2269e8f05258358ccc6fa63b43021b34538c2d54ae3c33d8f5a1"
  else
    url "https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-oss-7.17.25-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "770857949da51ce6cbde1445e03bb48de72faa3fd9db4e6cfd0024400f7b9e4b"
  end
  version "7.17.25"

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

  service do
    run opt_bin/"metricbeat"
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
