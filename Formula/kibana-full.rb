class KibanaFull < Formula
  desc "Analytics and search dashboard for Elasticsearch"
  homepage "https://www.elastic.co/products/kibana"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/kibana/kibana-7.15.1-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "7028495cafc4c3454d933b3bd938bfc3b7ee9042323df6013d7233306feac3ef"
  else
    url "https://artifacts.elastic.co/downloads/kibana/kibana-7.15.1-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "4e487dcd073b254431911ea4b092c83f29ac7d27bc0af252ce395bf677a8259a"
  end
  version "7.15.1"

  bottle :unneeded

  conflicts_with "kibana"

  def install
    libexec.install(
      "bin",
      "config",
      "data",
      "node",
      "node_modules",
      "package.json",
      "plugins",
      "src",
      "x-pack",
    )

    Pathname.glob(libexec/"bin/*") do |f|
      next if f.directory?
      bin.install libexec/"bin"/f
    end
    bin.env_script_all_files(libexec/"bin", { "KIBANA_PATH_CONF" => etc/"kibana", "DATA_PATH" => var/"lib/kibana/data" })

    cd libexec do
      packaged_config = IO.read "config/kibana.yml"
      IO.write "config/kibana.yml", "path.data: #{var}/lib/kibana/data\n" + packaged_config
      (etc/"kibana").install Dir["config/*"]
      rm_rf "config"
      rm_rf "data"
    end
  end

  def post_install
    (var/"lib/kibana/data").mkpath
    (prefix/"plugins").mkdir
  end

  def caveats; <<~EOS
    Config: #{etc}/kibana/
    If you wish to preserve your plugins upon upgrade, make a copy of
    #{opt_prefix}/plugins before upgrading, and copy it into the
    new keg location after upgrading.
  EOS
  end

  plist_options :manual => "kibana"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>Program</key>
        <string>#{opt_bin}/kibana</string>
        <key>RunAtLoad</key>
        <true/>
      </dict>
    </plist>
  EOS
  end

  test do
    ENV["BABEL_CACHE_PATH"] = testpath/".babelcache.json"
    assert_match /#{version}/, shell_output("#{bin}/kibana -V")
  end
end
