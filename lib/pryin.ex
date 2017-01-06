defmodule PryIn do
  use Application

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
