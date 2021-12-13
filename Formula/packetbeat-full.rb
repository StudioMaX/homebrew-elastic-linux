class PacketbeatFull < Formula
  desc "Lightweight Shipper for Network Data"
  homepage "https://www.elastic.co/products/beats/packetbeat"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/beats/packetbeat/packetbeat-7.16.0-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "74b9d383909593e5f5356c313fb5e362ee61dce6c9800b75a6dff2714a04edcc"
  else
    url "https://artifacts.elastic.co/downloads/beats/packetbeat/packetbeat-7.16.0-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "51b7556fc30d4801ce27abfd5c58d002eda73908baf8b3eb05ae00b00317f09d"
  end
  version "7.16.0"

  conflicts_with "packetbeat"
  conflicts_with "packetbeat-oss"

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
