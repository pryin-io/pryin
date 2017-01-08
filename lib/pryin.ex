defmodule PryIn do
  use Application
  @moduledoc """
  PryIn is a performance metrics platform for your Phoenix application.

  This is the main entry point for the client library.
  It starts an InteractonStore (which holds a list of interaction (e.g. web request) metrics)
  and a Forwarder (which polls the InteractionStore for metrics and forwards them to the api).
  """

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(PryIn.InteractionStore, []),
      worker(PryIn.Forwarder, []),
    ]

    opts = [strategy: :rest_for_one, name: PryIn.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
