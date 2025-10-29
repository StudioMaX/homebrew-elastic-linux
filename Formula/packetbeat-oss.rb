class PacketbeatOss < Formula
  arch arm: "arm64", intel: "x86_64"
  os macos: "darwin", linux: "linux"

  version "7.17.29"
  sha256 intel:        "7d188f3f128db44422eba4de1df391ecb0b4355eb288801578c39c202b668a95",
         arm64_linux:  "f92fb65e383c5247db8ce9fbbf2bb96f9168f33ef0f15d2a01bcf8ac60fb4d47",
         x86_64_linux: "7aa339947976127aa22dd477aee6569974ad5616a26d3460d4675cafec8cc7aa"

  url "https://artifacts.elastic.co/downloads/beats/packetbeat/packetbeat-oss-#{version}-#{os}-#{arch}.tar.gz?tap=elastic/homebrew-tap"
  desc "Lightweight Shipper for Network Data"
  homepage "https://www.elastic.co/products/beats/packetbeat"

  livecheck do
    url "https://me0ej585.api.sanity.io/v2022-03-25/data/query/production?query=*%5B_type+%3D%3D+%22product_versions%22+%26%26+references%28*%5B_type%3D%3D%22product_names%22+%26%26+lower%28title%29+%3D%3D+%22Packetbeat+OSS%22%5D._id%29%5D%7B%0A+version_number%2C%0A+%27v%27%3A+string%3A%3Asplit%28version_number%2C+%27.%27%29%0A+%7D+%7C+order%28%0A+length%28v%5B0%5D%29+desc%2C+v%5B0%5D+desc%2C%0A+length%28v%5B1%5D%29+desc%2C+v%5B1%5D+desc%2C%0A+length%28v%5B2%5D%29+desc%2C+v%5B2%5D+desc%2C%0A+%29&returnQuery=false"
    regex(/"version_number":"(#{Regexp.escape(version.major)}(?:\.\d+\.\d+)*)/i)
  end

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
