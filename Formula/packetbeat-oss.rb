class PacketbeatOss < Formula
  desc "Lightweight Shipper for Network Data"
  homepage "https://www.elastic.co/products/beats/packetbeat"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/beats/packetbeat/packetbeat-oss-7.17.2-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "40c3687d72a2bdbc418d34a68ae253000ec580b85ed3a3564ddd8c2c3882d713"
  else
    url "https://artifacts.elastic.co/downloads/beats/packetbeat/packetbeat-oss-7.17.0-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "e8c0cddfd4a31393cee44c2963feee8b2d19957b0fb676950a3c195c98f6f06a"
  end
  version "7.17.2"

  conflicts_with "packetbeat"
  conflicts_with "packetbeat-full"

  def install
    ["fields.yml", "ingest", "kibana", "module"].each { |d| libexec.install d if File.exist?(d) }
    (libexec/"bin").install "packetbeat"
    (etc/"packetbeat").install "packetbeat.yml"
    (etc/"packetbeat").install "modules.d" if File.exist?("modules.d")

    (bin/"packetbeat").write <<~EOS
      #!/bin/sh
      exec #{libexec}/bin/packetbeat \
        --path.config #{etc}/packetbeat \
        --path.data #{var}/lib/packetbeat \
        --path.home #{libexec} \
        --path.logs #{var}/log/packetbeat \
        "$@"
    EOS
  end

  plist_options :manual => "packetbeat"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>Program</key>
        <string>#{opt_bin}/packetbeat</string>
        <key>RunAtLoad</key>
        <true/>
      </dict>
    </plist>
  EOS
  end

  test do
    system "#{bin}/packetbeat", "devices"
  end
end
