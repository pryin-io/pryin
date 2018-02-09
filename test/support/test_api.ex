defmodule PryIn.Api.Test do
  @behaviour PryIn.Api
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def send_data(interactions) do
    GenServer.call(__MODULE__, {:send_data, interactions})
  end

  def send_system_metrics(data) do
    GenServer.call(__MODULE__, {:send_system_metrics, data})
  end

  def subscribe do
    GenServer.call(__MODULE__, {:subscribe, self()})
  end

  # Server

  def init(args) do
    {:ok, args}
  end

  def handle_call({:subscribe, pid}, _from, listeners) do
    {:reply, :ok, [pid | listeners]}
  end

  def handle_call({:send_data, data}, _from, listeners) do
    send_to_listeners(listeners, {:data_sent, data})
    {:reply, :ok, listeners}
  end

  def handle_call({:send_system_metrics, data}, _from, listeners) do
    send_to_listeners(listeners, {:system_metrics_sent, data})
    {:reply, :ok, listeners}
  end

  defp send_to_listeners(listeners, message) do
    for listener <- listeners do
      send(listener, message)
    end
  end
end
