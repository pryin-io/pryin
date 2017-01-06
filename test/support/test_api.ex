defmodule PryIn.Api.Test do
  @behaviour PryIn.Api
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def send_interactions(interactions) do
    GenServer.call(__MODULE__, {:send_interactions, interactions})
  end

  def subscribe do
    GenServer.call(__MODULE__, {:subscribe, self})
  end


  # Server

  def handle_call({:subscribe, pid}, _from, listeners) do
    {:reply, :ok, [pid | listeners]}
  end

  def handle_call({:send_interactions, interactions}, _from, listeners) do
    send_to_listeners(listeners, {:interactions_sent, interactions})
    {:reply, :ok, listeners}
  end


  defp send_to_listeners(listeners, message) do
    for listener <- listeners do
      send listener, message
    end
  end
end
