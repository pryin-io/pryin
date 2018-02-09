use Mix.Config

config :pryin,
  api: PryIn.Api.Test,
  env: :dev,
  otp_app: :exprotobuf,
  collect_system_metrics: false

config :phoenix, PryIn.TestEndpoint,
  instrumenters: [PryIn.Instrumenter],
  pubsub: [name: PryIn.PubSub, adapter: Phoenix.PubSub.PG2]

config :logger, level: :warn
