defmodule RethinkDB.Mixfile do use Mix.Project

  def project do
    [app: :rethinkdb,
     version: "0.4.0",
     elixir: "~> 1.0",
     description: "RethinkDB driver for Elixir",
     package: package,
     deps: deps,
     test_coverage: [tool: ExCoveralls]]
  end

  def package do
    [
      maintainers: ["Peter Hamilton"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/hamiltop/rethinkdb-elixir"}
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    env_apps = case Mix.env do
      :test -> [:flaky_connection]
      _ -> []
    end
    [applications: [:logger, :poison, :connection | env_apps]]
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
      {:poison, "~> 1.5 or ~> 2.0"},
      {:earmark, "~> 0.1", only: :dev},
      {:ex_doc, "~> 0.7", only: :dev},
      {:flaky_connection, github: "hamiltop/flaky_connection", only: :test},
      {:connection, "~> 1.0.1"},
      {:excoveralls, "~> 0.3.11", only: :test},
      {:dialyze, "~> 0.2.0", only: :test}
    ]
  end
end
