defmodule Skope do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Skope.InteractionStore, []),
      worker(Skope.Forwarder, []),
    ]

    opts = [strategy: :rest_for_one, name: Skope.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
