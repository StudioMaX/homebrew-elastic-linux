class HeartbeatOss < Formula
  desc "Lightweight Shipper for Uptime Monitoring"
  homepage "https://www.elastic.co/products/beats/heartbeat"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/beats/heartbeat/heartbeat-oss-7.14.0-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "ab0fbf7bb2c92fb9ab97b7caeb6ffbed29ddf898e8193cbb6b9fab7f64bbda21"
  else
    url "https://artifacts.elastic.co/downloads/beats/heartbeat/heartbeat-oss-7.14.0-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "1093a9738a05602648585e65a3fcc3111668534a1ba22876e172e1418d03107a"
  end
  version "7.14.0"

  bottle :unneeded

  conflicts_with "heartbeat"
  conflicts_with "heartbeat-full"

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
