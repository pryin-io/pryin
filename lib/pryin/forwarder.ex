defmodule PryIn.Forwarder do
  use GenServer
  require Logger
  alias PryIn.{InteractionStore, Data}

  @moduledoc """
  Polls for metrics and forwards them to the API.
  Polling interval can be configured with
  `config :pryin, :forward_interval, 1000`.
  API restrictions may apply.
  """

  @api Application.get_env(:pryin, :api, PryIn.Api.Live)
  @env Application.get_env(:pryin, :env)
  unless @env in [:dev, :staging, :prod], do: raise """
  PryIn `env` configuration needs to be one of :dev, :staging, :prod.
  Got #{inspect @env}.
  """


  # CLIENT

  @doc false
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
      Data.new(env: @env, interactions: interactions)
      |> Data.encode
      |> @api.send_data
    end
    Process.send_after(self, :forward_interactions, forward_interval_millis)

    {:noreply, state}
  end

  defp forward_interval_millis do
    Application.get_env(:pryin, :forward_interval, 1000)
  end
end
