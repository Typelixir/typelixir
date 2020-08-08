defmodule Typelixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :typelixir,
      version: "0.1.0",
      elixir: "~> 1.10.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [{:ex_doc, ">= 0.0.0", only: :dev, runtime: false}]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/mcass19/typelixir"},
      maintainers: ["Mauricio Cassola", "Agustín Talagorría"],
      name: :typelixir,
    ]
  end

  defp description do
    """
    Library to compile Elixir statically. 
    """
  end
end
