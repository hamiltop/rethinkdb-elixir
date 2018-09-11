defmodule RethinkDB.Mixfile do
  use Mix.Project

  def project do
    [
      app: :rethinkdb,
      version: "0.4.0",
      elixir: "~> 1.0",
      description: "RethinkDB driver for Elixir",
      package: package(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
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
    env_apps =
      case Mix.env() do
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
      {:poison, "~> 3.1"},
      {:ex_doc, "~> 0.18", only: :dev},
      {:flaky_connection, github: "norpan/flaky_connection", only: :test},
      {:connection, "~> 1.0"},
      {:excoveralls, "~> 0.8", only: :test},
      {:dialyxir, "~> 0.5", only: :dev}
    ]
  end
end
