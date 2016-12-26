use Mix.Config

config :skope, :api, Skope.Api.Test
config :skope, :env, "test"

config :phoenix, Skope.TestEndpoint,
  instrumenters: [Skope.Instrumenter]

config :logger, level: :warn
