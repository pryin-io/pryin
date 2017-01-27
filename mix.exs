defmodule PryIn.Mixfile do
  use Mix.Project

  def project do
    [app: :pryin,
     version: "0.1.0",
     elixir: "~> 1.3",
     elixirc_paths: elixirc_paths(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     compilers: compilers(Mix.env),
     deps: deps(),
     name: "PryIn",
     source_url: "https://github.com/pryin-io/pryin",
     homepage_url: "http://pryin.io",
     docs: [main: "readme",
            #logo: "path/to/logo.png",
            extras: ["README.md"]]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :httpoison, :exprotobuf],
     mod: {PryIn, []}]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp compilers(:test), do: [:phoenix] ++ Mix.compilers
  defp compilers(_), do: Mix.compilers

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:plug, "~> 1.0", optional: true},
      {:phoenix, "~> 1.2", optional: true},
      {:ecto, "~> 2.0", optional: true},
      {:httpoison, "~> 0.10.0"},
      {:exprotobuf, "~> 1.2"},
      {:ex_doc, "~> 0.14.5", only: :dev},
    ]
  end
end
