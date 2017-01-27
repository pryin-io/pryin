use Mix.Config

config :pryin, :api, PryIn.Api.Test
config :pryin, :env, :dev

config :phoenix, PryIn.TestEndpoint,
  instrumenters: [PryIn.Instrumenter]

config :logger, level: :warn
