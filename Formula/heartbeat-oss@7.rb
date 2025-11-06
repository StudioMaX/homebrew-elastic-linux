class HeartbeatOssAT7 < Formula
  desc "Lightweight Shipper for Uptime Monitoring"
  homepage "https://www.elastic.co/products/beats/heartbeat"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/beats/heartbeat/heartbeat-oss-7.17.4-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "562775948127b9b4621f220fdb219e5a6f0c48a55a7b75916da8a77a18b47d26"
  else
    url "https://artifacts.elastic.co/downloads/beats/heartbeat/heartbeat-oss-7.17.29-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "cc8d50bf099d0c86c3ff4609c1bff3f798c71966de711a0b3f1452d08cb0ee82"
  end

  livecheck do
    url "https://me0ej585.api.sanity.io/v2022-03-25/data/query/production?query=*%5B_type+%3D%3D+%22product_versions%22+%26%26+references%28*%5B_type%3D%3D%22product_names%22+%26%26+lower%28title%29+%3D%3D+%22Heartbeat+OSS%22%5D._id%29%5D%7B%0A+version_number%2C%0A+%27v%27%3A+string%3A%3Asplit%28version_number%2C+%27.%27%29%0A+%7D+%7C+order%28%0A+length%28v%5B0%5D%29+desc%2C+v%5B0%5D+desc%2C%0A+length%28v%5B1%5D%29+desc%2C+v%5B1%5D+desc%2C%0A+length%28v%5B2%5D%29+desc%2C+v%5B2%5D+desc%2C%0A+%29&returnQuery=false"
    regex(/"version_number":"(#{Regexp.escape(version.major)}(?:\.\d+\.\d+)*)/i)
  end

  keg_only :versioned_formula

  deprecate! date: "2026-01-15", because: :unsupported

  def install
    ["fields.yml", "ingest", "kibana", "module"].each { |d| libexec.install d if File.exist?(d) }
    (libexec/"bin").install "heartbeat"
    (etc/"heartbeat").install "heartbeat.yml"
    (etc/"heartbeat").install "modules.d" if File.exist?("modules.d")

    (bin/"heartbeat").write <<~EOS
      #!/bin/sh
      exec #{libexec}/bin/heartbeat \
        --path.config #{etc}/heartbeat \
        --path.data #{var}/lib/heartbeat \
        --path.home #{libexec} \
        --path.logs #{var}/log/heartbeat \
        "$@"
    EOS
  end

  def post_install
    (var/"lib/heartbeat").mkpath
    (var/"log/heartbeat").mkpath
  end

  service do
    run opt_bin/"heartbeat"
  end

  test do
    require "socket"

    server = TCPServer.new(0)
    port = server.addr[1]

    (testpath/"config/heartbeat.yml").write <<~EOS
      heartbeat.monitors:
      - type: tcp
        schedule: '@every 5s'
        hosts: ["localhost:#{port}"]
        check.send: "r u there\\n"
        check.receive: "i am here\\n"
      output.file:
        path: "#{testpath}/heartbeat"
        filename: heartbeat
        codec.format:
          string: '%{[monitor]}'
    EOS
    chmod "go-w", testpath/"config/heartbeat.yml" unless OS.mac?
    pid = fork do
      exec bin/"heartbeat", "-path.config", testpath/"config", "-path.data",
                            testpath/"data"
    end
    sleep 5

    t = nil
    begin
      t = Thread.new do
        loop do
          client = server.accept
          line = client.readline
          if line == "r u there\n"
            client.puts("i am here\n")
          else
            client.puts("goodbye\n")
          end
          client.close
        end
      end
      sleep 5
      assert_match "\"status\":\"up\"", (testpath/"heartbeat/heartbeat").read
    ensure
      Process.kill "SIGINT", pid
      Process.wait pid
      t.exit
      server.close
    end
  end
end
