class KibanaFullAT7 < Formula
  desc "Analytics and search dashboard for Elasticsearch"
  homepage "https://www.elastic.co/products/kibana"
  if OS.mac?
    url "https://artifacts.elastic.co/downloads/kibana/kibana-7.17.4-darwin-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "ac2b5a639ad83431db25e4161f811111d45db052eb845091e18f847016a34a55"
  else
    url "https://artifacts.elastic.co/downloads/kibana/kibana-7.17.29-linux-x86_64.tar.gz?tap=elastic/homebrew-tap"
    sha256 "33be2214371907def42abb8db6cd86fb36faa3883cfc2bf128b1d20b55267d43"
  end

  livecheck do
    url "https://me0ej585.api.sanity.io/v2022-03-25/data/query/production?query=*%5B_type+%3D%3D+%22product_versions%22+%26%26+references%28*%5B_type%3D%3D%22product_names%22+%26%26+lower%28title%29+%3D%3D+%22Kibana%22%5D._id%29%5D%7B%0A+version_number%2C%0A+%27v%27%3A+string%3A%3Asplit%28version_number%2C+%27.%27%29%0A+%7D+%7C+order%28%0A+length%28v%5B0%5D%29+desc%2C+v%5B0%5D+desc%2C%0A+length%28v%5B1%5D%29+desc%2C+v%5B1%5D+desc%2C%0A+length%28v%5B2%5D%29+desc%2C+v%5B2%5D+desc%2C%0A+%29&returnQuery=false"
    regex(/"version_number":"(#{Regexp.escape(version.major)}(?:\.\d+\.\d+)*)/i)
  end

  keg_only :versioned_formula

  deprecate! date: "2026-01-15", because: :unsupported

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
    bin.env_script_all_files(libexec/"bin", KBN_PATH_CONF: etc/"kibana")

    cd libexec do
      config_file = libexec/"config/kibana.yml"
      packaged_config = config_file.read
      config_file.unlink if config_file.exist?
      config_file.write "path.data: #{var}/lib/kibana/data\n" + packaged_config
      (etc/"kibana").install Dir["config/*"]
      rm_r("config")
      rm_r("data")
    end
  end

  def post_install
    (var/"lib/kibana/data").mkpath
    (prefix/"plugins").mkdir
  end

  def caveats
    <<~EOS
      Config: #{etc}/kibana/
      If you wish to preserve your plugins upon upgrade, make a copy of
      #{opt_prefix}/plugins before upgrading, and copy it into the
      new keg location after upgrading.
    EOS
  end

  service do
    run opt_bin/"kibana"
  end

  test do
    ENV["BABEL_CACHE_PATH"] = testpath/".babelcache.json"
    assert_match version.to_s, shell_output("#{bin}/kibana -V")
  end
end
