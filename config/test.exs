use Mix.Config

config :pryin,
  api: PryIn.Api.Test,
  env: :dev,
  otp_app: :exprotobuf

config :phoenix, PryIn.TestEndpoint,
  instrumenters: [PryIn.Instrumenter]

config :logger, level: :warn
