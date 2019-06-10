defmodule LogflareLogger.MixProject do
  use Mix.Project

  def project do
    [
      app: :logflare_logger_backend,
      version: "0.4.0",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:mix_test_watch, ">= 0.9.0", only: :dev, runtime: false},
      {:jason, "~> 1.0"},
      {:bypass, "~> 1.0", only: :test},
      {:tesla, "~> 1.2.1"},
      {:cachex, "~> 3.0"},
      {:timex, "~> 3.0"},
      {:typed_struct, ">= 0.0.0"},
      {:bertex, "~> 1.3"},
      {:iteraptor, ">= 0.0.0"},
      {:mox, "~> 0.5", only: :test},
      {:hackney, "~> 1.10"},
      {:placebo, "~> 1.2"}
    ]
  end
end
