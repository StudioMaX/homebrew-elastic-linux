class PacketbeatFull < Formula
  desc "Lightweight Shipper for Network Data"
  homepage "https://www.elastic.co/products/beats/packetbeat"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/beats/packetbeat/packetbeat-7.17.4-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "d88fa66db92405cb2c440f772fde288050beeb272a7582c8a958d3f697e51609"
  else
    url "https://artifacts.elastic.co/downloads/beats/packetbeat/packetbeat-7.17.28-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "bd7f8f7d9296fa1cbd88b69e37851c826359c96e5db06ee57f1db161699a1531"
  end
  version "7.17.28"

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

  service do
    run opt_bin/"packetbeat"
  end

  test do
    system "#{bin}/packetbeat", "devices"
  end
end
