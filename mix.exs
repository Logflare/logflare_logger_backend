defmodule LogflareLogger.MixProject do
  use Mix.Project

  def project do
    [
      app: :logflare_logger_backend,
      version: "0.8.0-rc.2",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "Logflare Logger Backend",
      source_url: "https://github.com/Logflare/logflare_logger_backend",
      homepage_url: "https://logflare.app",
      docs: [
        main: "readme",
        # logo: "path/to/logo.png",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {LogflareLogger.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:jason, "~> 1.0"},
      {:bypass, "~> 2.0", only: :test},
      {:tesla, "~> 1.3"},
      {:typed_struct, ">= 0.0.0"},
      {:bertex, "~> 1.3"},
      {:hackney, "~> 1.10"},
      {:placebo, "~> 2.0", only: :test},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:etso, "~> 0.1.2"},
      {:logflare_api_client, "~> 0.3.0"}
    ]
  end

  defp description() do
    "Easily ship structured logs and log based metrics to Logflare with the Logflare Logger backend."
  end

  defp package() do
    [
      links: %{"GitHub" => "https://github.com/Logflare/logflare_logger_backend"},
      licenses: ["MIT"]
    ]
  end
end
