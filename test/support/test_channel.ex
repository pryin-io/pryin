defmodule PryIn.TestChannel do
  use Phoenix.Channel
  require Logger

  def join("test:topic", _message, socket) do
    {:ok, socket}
  end

  def handle_in("test:msg", _msg, socket) do
    {:reply, :ok, socket}
  end
end
