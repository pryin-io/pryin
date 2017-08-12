defmodule PryIn.InteractionForwarder do
  use GenServer
  require Logger
  alias PryIn.{InteractionStore, BaseForwarder}

  @moduledoc """
  Polls for metrics and forwards them to the API.
  Polling interval can be configured with
  `config :pryin, :forward_interval, 1000`.
  API restrictions may apply.
  """


  # CLIENT

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end


  # SERVER
  def init(state) do
    Process.send_after(self(), :forward_interactions, forward_interval_millis())
    {:ok, state}
  end

  def handle_info(:forward_interactions, state) do
    interactions = InteractionStore.pop_finished_interactions()

    if Enum.any?(interactions) do
      [interactions: interactions]
      |> BaseForwarder.wrap_data()
      |> BaseForwarder.api().send_interactions
    end
    Process.send_after(self(), :forward_interactions, forward_interval_millis())

    {:noreply, state}
  end

  defp forward_interval_millis do
    Application.get_env(:pryin, :forward_interval, 1000)
  end
end
