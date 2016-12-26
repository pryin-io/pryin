defmodule Skope.Forwarder do
  use GenServer
  require Logger
  alias Skope.InteractionStore

  @moduledoc """
  Polls for metrics and forwards them to the API.
  Polling interval can be configured with
  `config :skope, :forward_interval, 1000`.
  API restrictions may apply.
  """

  @api Application.get_env(:skope, :api, Skope.Api.Live)


  # CLIENT

  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end


  # SERVER
  def init(state) do
    Process.send_after(self, :forward_interactions, forward_interval_millis)
    {:ok, state}
  end

  def handle_info(:forward_interactions, state) do
    interactions = InteractionStore.pop_finished_interactions()

    if Enum.any?(interactions) do
      @api.send_interactions(interactions)
    end
    Process.send_after(self, :forward_interactions, forward_interval_millis)

    {:noreply, state}
  end

  defp forward_interval_millis do
    Application.get_env(:skope, :forward_interval, 1000)
  end
end
