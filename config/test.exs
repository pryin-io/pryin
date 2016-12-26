use Mix.Config

config :skope, :api, Skope.Api.Test
config :phoenix, Skope.TestEndpoint,
  instrumenters: [Skope.Instrumenter]
