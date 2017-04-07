defmodule PryIn do
  for file <- Path.wildcard("lib/proto/*.proto") do
    @external_resource file
  end
  use Protobuf, from: Path.wildcard("lib/proto/*.proto")
  use Application
  @moduledoc """
  PryIn is a performance metrics platform for your Phoenix application.

  This is the main entry point for the client library.
  It starts an InteractionStore (which holds a list of interaction (e.g. web request) metrics)
  and a InteractionForwarder (which polls the InteractionStore for metrics and forwards them to the api).
  """

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      :hackney_pool.child_spec(:pryin_pool, [timeout: 60_000, max_connections: 5]),
      worker(PryIn.InteractionStore, []),
      worker(PryIn.InteractionForwarder, []),
      worker(PryIn.SystemMetricsCollector, []),
    ]

    opts = [strategy: :rest_for_one, name: PryIn.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
