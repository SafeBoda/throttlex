defmodule Throttlex.MixProject do
  use Mix.Project

  @version "1.0.0-dev"

  def project do
    [
      app: :throttlex,
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      elixirc_options: [warnings_as_errors: true],

      # Testing
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],

      # Dialyzer
      dialyzer: dialyzer(),

      # Hex
      package: package(),
      description: "Throttle/Circuit Breaker Utilities"
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Test
      {:excoveralls, "~> 0.12", only: :test},

      # Code Analysis
      {:dialyxir, "~> 0.5", optional: true, only: [:dev, :test], runtime: false},
      {:credo, "~> 1.3", optional: true, only: [:dev, :test]},

      # Docs
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: :throttlex,
      maintainers: [
        "Carlos A. Bolaños",
        "Raphael D. Pinheiro"
      ],
      links: %{"GitHub" => "https://github.com/SafeBoda/throttlex"}
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [
        :mix,
        :eex,
        :ex_unit
      ],
      flags: [
        :unmatched_returns,
        :error_handling,
        :race_conditions,
        :no_opaque,
        :unknown,
        :no_return
      ]
    ]
  end
end
