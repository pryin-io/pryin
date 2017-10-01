defmodule PryIn.DataForwarder do
  use GenServer
  require Logger
  alias PryIn.{InteractionStore, BaseForwarder, MetricValueStore}

  @moduledoc false

  # Polls for metrics and forwards them to the API.
  # Polling interval can be configured with
  # `config :pryin, :forward_interval, 1000`.
  # API restrictions may apply.


  # CLIENT

  @doc false
  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end


  # SERVER
  def init(state) do
    Process.send_after(self(), :forward_data, forward_interval_millis())
    {:ok, state}
  end

  def handle_info(:forward_data, state) do
    interactions = InteractionStore.pop_finished_interactions()
    metric_values = MetricValueStore.pop_metric_values()

    if Enum.any?(interactions) || Enum.any?(metric_values) do
      [interactions: interactions, metric_values: metric_values]
      |> BaseForwarder.wrap_data
      |> BaseForwarder.api().send_data
    end
    Process.send_after(self(), :forward_data, forward_interval_millis())

    {:noreply, state}
  end

  defp forward_interval_millis do
    Application.get_env(:pryin, :forward_interval, 1000)
  end
end
