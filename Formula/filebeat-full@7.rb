class FilebeatFullAT7 < Formula
  desc "File harvester to ship log files to Elasticsearch or Logstash"
  homepage "https://www.elastic.co/products/beats/filebeat"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.17.4-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "886ef38ec0656fb11a76a80fd9f0a83fa314b1a32b4f1f176d253ef05b0a7fc0"
  else
    url "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.17.29-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "7d316028c7817ca9151c2174ef4b150eda049c14e648ac46240246ff48651032"
  end

  livecheck do
    url "https://me0ej585.api.sanity.io/v2022-03-25/data/query/production?query=*%5B_type+%3D%3D+%22product_versions%22+%26%26+references%28*%5B_type%3D%3D%22product_names%22+%26%26+lower%28title%29+%3D%3D+%22Filebeat%22%5D._id%29%5D%7B%0A+version_number%2C%0A+%27v%27%3A+string%3A%3Asplit%28version_number%2C+%27.%27%29%0A+%7D+%7C+order%28%0A+length%28v%5B0%5D%29+desc%2C+v%5B0%5D+desc%2C%0A+length%28v%5B1%5D%29+desc%2C+v%5B1%5D+desc%2C%0A+length%28v%5B2%5D%29+desc%2C+v%5B2%5D+desc%2C%0A+%29&returnQuery=false"
    regex(/"version_number":"(#{Regexp.escape(version.major)}(?:\.\d+\.\d+)*)/i)
  end

  keg_only :versioned_formula

  deprecate! date: "2026-01-15", because: :unsupported

  conflicts_with "filebeat"
  conflicts_with "filebeat-oss@7"

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

  service do
    run opt_bin/"filebeat"
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

      assert_path_exists testpath/"filebeat"
    ensure
      Process.kill("TERM", filebeat_pid)
    end
  end
end
