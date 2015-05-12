defmodule RethinkDB.Mixfile do
  use Mix.Project

  def project do
    [app: :rethinkdb,
     version: "0.0.3",
     elixir: "~> 1.0",
     description: "RethinkDB driver for Elixir",
     package: package,
     deps: deps]
  end

  def package do
    [
      contributors: ["Peter Hamilton"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/hamiltop/exrethinkdb"}
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :poison]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:poison, "1.4.0"},
      {:earmark, "~> 0.1", only: :dev},
      {:ex_doc, "~> 0.7", only: :dev},
      {:inch_ex, only: :dev}
    ]
  end
end
