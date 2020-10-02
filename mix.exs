defmodule Examine.MixProject do
  use Mix.Project

  @source_url "https://github.com/mbgardner/examine"

  def project do
    [
      app: :examine,
      version: "0.3.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      description: "Enhanced inspect debugging."
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Examine",
      source_url: @source_url
    ]
  end

  defp package() do
    [
      maintainers: ["Matthew Gardner"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
