defmodule LogflareLogger.MixProject do
  use Mix.Project

  def project do
    [
      app: :logflare_logger,
      version: "0.1.0",
      elixir: "~> 1.8",
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

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mix_test_watch, ">= 0.9.0"},
      {:jason, "~> 1.0"},
      {:bypass, "~> 1.0", only: :test},
      {:tesla, "~> 1.2.1"},
      {:cachex, "~> 3.1"}
      {:typed_struct, ">= 0.0.0"}
    ]
  end
end
