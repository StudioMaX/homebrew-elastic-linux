class ApmServerFull < Formula
  arch arm: "arm64", intel: "x86_64"
  os macos: "darwin", linux: "linux"

  version "7.17.29"
  sha256 intel:        "ff3c35239d41e892be33b1172ee72d1af0f637d2bf4396058487e4635c382eff",
         arm64_linux:  "789fc3b285ec05d71755d3d39286f9c9a06919a47bfe3a1dcf711dd25a940eca",
         x86_64_linux: "f03d37df903902ec2a07027678f6bfa27abb64811c7348f1023ef8f64e493f08"

  url "https://artifacts.elastic.co/downloads/apm-server/apm-server-#{version}-#{os}-#{arch}.tar.gz?tap=elastic/homebrew-tap"
  desc "Server for shipping APM metrics to Elasticsearch"
  homepage "https://www.elastic.co/"

  livecheck do
    url "https://me0ej585.api.sanity.io/v2022-03-25/data/query/production?query=*%5B_type+%3D%3D+%22product_versions%22+%26%26+references%28*%5B_type%3D%3D%22product_names%22+%26%26+lower%28title%29+%3D%3D+%22APM+Server%22%5D._id%29%5D%7B%0A+version_number%2C%0A+%27v%27%3A+string%3A%3Asplit%28version_number%2C+%27.%27%29%0A+%7D+%7C+order%28%0A+length%28v%5B0%5D%29+desc%2C+v%5B0%5D+desc%2C%0A+length%28v%5B1%5D%29+desc%2C+v%5B1%5D+desc%2C%0A+length%28v%5B2%5D%29+desc%2C+v%5B2%5D+desc%2C%0A+%29&returnQuery=false"
    regex(/"version_number":"(#{Regexp.escape(version.major)}(?:\.\d+\.\d+)*)/i)
  end

  conflicts_with "apm-server-oss"

  def install
    ["fields.yml", "ingest", "kibana", "module"].each { |d| libexec.install d if File.exist?(d) }
    (libexec/"bin").install "apm-server"
    (etc/"apm-server").install "apm-server.yml"
    (etc/"apm-server").install "modules.d" if File.exist?("modules.d")

    (bin/"apm-server").write <<~EOS
      #!/bin/sh
      exec #{libexec}/bin/apm-server \
        --path.config #{etc}/apm-server \
        --path.home #{libexec} \
        --path.logs #{var}/log/apm-server \
        --path.data #{var}/lib/apm-server \
        "$@"
    EOS
  end

  def post_install
    (var/"lib/apm-server").mkpath
    (var/"log/apm-server").mkpath
  end

  service do
    run opt_bin/"apm-server"
  end

  test do
    require "socket"

    server = TCPServer.new(0)
    port = server.addr[1]
    server.close

    (testpath/"config/apm-server.yml").write <<~EOS
      apm-server:
        host: localhost:#{port}
      output.file:
        path: "#{testpath}/apm-server"
        filename: apm-server
        codec.format:
          string: '%{[transaction]}'
    EOS
    chmod "go-w", testpath/"config/apm-server.yml" unless OS.mac?
    pid = fork do
      exec bin/"apm-server", "-path.config", testpath/"config", "-path.data", testpath/"data"
    end
    sleep 5

    begin
      (testpath/"event").write <<~EOS
        {
          "metadata": {
            "process": { "pid": 1234 },
            "system": {
              "container": { "id": "container-id" },
              "kubernetes": {
                "namespace": "namespace1",
                "pod": { "uid": "pod-uid", "name": "pod-name" },
                "node": { "name": "node-name" }
              }
            },
            "service": {
              "name": "1234_service-12a3",
              "language": { "name": "ecmascript" },
              "agent": { "version": "3.14.0", "name": "elastic-node" },
              "framework": { "name": "emac" }
            }
          }
        }
        {
          "error": {
            "id": "abcdef0123456789",
            "timestamp": 1533827045999000,
            "log": {
              "level": "custom log level",
              "message": "Cannot read property 'baz' of undefined"
            }
          }
        }
        {
          "span": {
            "id": "0123456a89012345",
            "trace_id": "0123456789abcdef0123456789abcdef",
            "parent_id": "ab23456a89012345",
            "transaction_id": "ab23456a89012345",
            "parent": 1,
            "name": "GET /api/types",
            "type": "request.external",
            "action": "get",
            "start": 1.845,
            "duration": 3.5642981,
            "stacktrace": [],
            "context": {}
          }
        }
        {
          "transaction": {
            "trace_id": "01234567890123456789abcdefabcdef",
            "id": "abcdef1478523690",
            "type": "request",
            "duration": 32.592981,
            "timestamp": 1535655207154000,
            "result": "200",
            "context": null,
            "spans": null,
            "sampled": null,
            "span_count": { "started": 0 }
          }
        }
        {
          "metricset": {
            "samples": { "go.memstats.heap.sys.bytes": { "value": 61235 } },
            "timestamp": 1496170422281000
          }
        }
      EOS
      system "curl", "-H", "Content-Type: application/x-ndjson", "-XPOST",
             "localhost:#{port}/intake/v2/events", "--data-binary", "@#{testpath}/event"
      sleep 5
      s = (testpath/"apm-server/apm-server").read
      assert_match "\"id\":\"abcdef1478523690\"", s
    ensure
      Process.kill "SIGINT", pid
      Process.wait pid
    end
  end
end
