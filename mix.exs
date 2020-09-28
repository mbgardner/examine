defmodule Examine.MixProject do
  use Mix.Project

  def project do
    [
      app: :examine,
      version: "0.2.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      description: "Enhanced inspect debugging."
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Examine",
      source_url: "https://github.com/mbgardner/examine"
    ]
  end

  defp package() do
    [
      maintainers: ["Matthew Gardner"],
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/mbgardner/examine"}
    ]
  end
end
