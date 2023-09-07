class PacketbeatOss < Formula
  desc "Lightweight Shipper for Network Data"
  homepage "https://www.elastic.co/products/beats/packetbeat"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/beats/packetbeat/packetbeat-oss-7.17.4-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "033e7603e5791842f1a2ced491f1c9d3c8eb7083232210271218b83695e86f6f"
  else
    url "https://artifacts.elastic.co/downloads/beats/packetbeat/packetbeat-oss-7.17.13-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "dd155f8d4997862634c41ef191daa919f5525d558fe53767438d93d8a125a0d3"
  end
  version "7.17.13"

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

  service do
    run opt_bin/"packetbeat"
  end

  test do
    system "#{bin}/packetbeat", "devices"
  end
end
