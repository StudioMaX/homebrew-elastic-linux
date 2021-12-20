class HeartbeatFull < Formula
  desc "Lightweight Shipper for Uptime Monitoring"
  homepage "https://www.elastic.co/products/beats/heartbeat"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/beats/heartbeat/heartbeat-7.16.2-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "6c267d9b32113f5b76c0e7680908b002d765f0afab85736ca9d1f32b252d0b44"
  else
    url "https://artifacts.elastic.co/downloads/beats/heartbeat/heartbeat-7.16.2-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "0301a36406aee41cba9dbdb3511f882f0c6c79ded9e25551566befa2b59bad4f"
  end
  version "7.16.2"

  conflicts_with "heartbeat"
  conflicts_with "heartbeat-oss"

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

  plist_options :manual => "heartbeat"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>Program</key>
        <string>#{opt_bin}/heartbeat</string>
        <key>RunAtLoad</key>
        <true/>
      </dict>
    </plist>
  EOS
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
