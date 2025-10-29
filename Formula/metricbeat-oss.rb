class MetricbeatOss < Formula
  arch arm: "arm64", intel: "x86_64"
  os macos: "darwin", linux: "linux"

  version "7.17.29"
  sha256 intel:        "131f463ad29b6e9f94ea27b2597df383ed96107089433d392b13062d7445ae30",
         arm64_linux:  "8df7434a28ddfbbbcd5509e61fc2563d7c5618c055f9df7659addbe1513f3122",
         x86_64_linux: "577c3bb46214b0aa4a91cb6dccd9da094c5e35fe72b1fd612648f9151d1486cb"

  url "https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-oss-#{version}-#{os}-#{arch}.tar.gz?tap=elastic/homebrew-tap"
  desc "Collect metrics from your systems and services"
  homepage "https://www.elastic.co/products/beats/metricbeat"

  livecheck do
    url "https://me0ej585.api.sanity.io/v2022-03-25/data/query/production?query=*%5B_type+%3D%3D+%22product_versions%22+%26%26+references%28*%5B_type%3D%3D%22product_names%22+%26%26+lower%28title%29+%3D%3D+%22Metricbeat+OSS%22%5D._id%29%5D%7B%0A+version_number%2C%0A+%27v%27%3A+string%3A%3Asplit%28version_number%2C+%27.%27%29%0A+%7D+%7C+order%28%0A+length%28v%5B0%5D%29+desc%2C+v%5B0%5D+desc%2C%0A+length%28v%5B1%5D%29+desc%2C+v%5B1%5D+desc%2C%0A+length%28v%5B2%5D%29+desc%2C+v%5B2%5D+desc%2C%0A+%29&returnQuery=false"
    regex(/"version_number":"(#{Regexp.escape(version.major)}(?:\.\d+\.\d+)*)/i)
  end

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
      assert_path_exists testpath/"data/metricbeat"
    ensure
      Process.kill "SIGINT", pid
      Process.wait pid
    end
  end
end
