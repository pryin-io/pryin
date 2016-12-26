defmodule Skope.InteractionStore do
  use GenServer
  require Logger
  defstruct [size: 0, running_interactions: %{}, monitor_refs: %{}, finished_interactions: []]

  @moduledoc """
  Stores interactions that will later be forwarded by the forwarder.
  When a certain amount of interactions is in the store, further interactions will simply be dropped.
  When the stored interactions are forwarded, the limit is reset.
  This amount can be configured with:
  `config :skope, :max_interactions_for_interval, 100`
  """

  # CLIENT

  def start_link() do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  def start_interaction(pid, interaction) do
    GenServer.cast(__MODULE__, {:start_interaction, pid, interaction})
  end

  def set_interaction_data(pid, data) do
    GenServer.cast(__MODULE__, {:set_interaction_data, pid, data})
  end

  def add_extra_data(pid, extra_data) do
    GenServer.cast(__MODULE__, {:add_extra_data, pid, extra_data})
  end

  def finish_interaction(pid) do
    GenServer.cast(__MODULE__, {:finish_interaction, pid})
  end

  def has_pid?(pid) do
    GenServer.call(__MODULE__, {:has_pid, pid})
  end

  def get_field(pid, field) do
    GenServer.call(__MODULE__, {:get_field, pid, field})
  end

  def pop_finished_interactions do
    GenServer.call(__MODULE__, :pop_finished_interactions)
  end


  # for testing

  def get_interaction(pid) do
    GenServer.call(__MODULE__, {:get_interaction, pid})
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def reset_state do
    GenServer.call(__MODULE__, :reset_state)
  end


  # SERVER

  def handle_cast({:start_interaction, pid, interaction}, state) do
    if state.size >= max_interactions do
      Logger.warn("Dropping interaction #{inspect pid} because buffer is full.")
      {:noreply, state}
    else
      monitor_refs = Map.put(state.monitor_refs, pid, Process.monitor(pid))
      running_interactions = Map.put(state.running_interactions, pid, interaction)
      {:noreply, %{state |
                   running_interactions: running_interactions,
                   monitor_refs: monitor_refs,
                   size: state.size + 1}}
    end
  end

  def handle_cast({:set_interaction_data, pid, data}, state) do
    interaction = state.running_interactions
    |> Map.get(pid)
    |> Map.merge(data)
    running_interactions = %{state.running_interactions | pid => interaction}
    {:noreply, %{state | running_interactions: running_interactions}}
  end

  def handle_cast({:add_extra_data, pid, extra_data}, state) do
    interaction = Map.get(state.running_interactions, pid)
    case interaction do
      nil ->
        {:noreply, state}
      interaction ->
        interaction = Map.update!(interaction, :extra_data, &([extra_data | &1]))
        running_interactions = %{state.running_interactions | pid => interaction}
        {:noreply, %{state | running_interactions: running_interactions}}
    end
  end

  def handle_cast({:finish_interaction, pid}, state) do
    {monitor_ref, remaining_monitor_refs} = Map.pop(state.monitor_refs, pid)
    Process.demonitor(monitor_ref)
    {finished_interaction, running_interactions} = Map.pop(state.running_interactions, pid)
    finished_interaction = Map.update!(finished_interaction, :start_time, &trunc(&1 / 1000))

    Logger.debug("finished interaction: #{inspect finished_interaction}")

    {:noreply, %{state |
                 running_interactions: running_interactions,
                 monitor_refs: remaining_monitor_refs,
                 finished_interactions: [finished_interaction | state.finished_interactions]}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {monitor_ref, remaining_monitor_refs} = Map.pop(state.monitor_refs, pid)
    unless is_nil(monitor_ref), do: Process.demonitor(monitor_ref)
    {down_interaction, running_interactions} = Map.pop(state.running_interactions, pid)
    size = if down_interaction do
      Logger.warn("[InteractionStore] Interaction #{inspect pid} down before finished.")
      state.size - 1
    else
      state.size
    end

    {:noreply, %{state |
                 running_interactions: running_interactions,
                 monitor_refs: remaining_monitor_refs,
                 size: size}}
  end

  def handle_call({:has_pid, pid}, _from, state) do
    result = pid in Map.keys(state.running_interactions)
    {:reply, result, state}
  end

  def handle_call({:get_field, pid, field}, _from, state) do
    interaction = Map.get(state.running_interactions, pid)
    result = Map.get(interaction, field)
    {:reply, result, state}
  end

  def handle_call({:get_interaction, pid}, _from, state) do
    interaction = Map.get(state.running_interactions, pid)
    {:reply, interaction, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:reset_state, _from, _state) do
    {:reply, :ok, %__MODULE__{}}
  end

  def handle_call(:pop_finished_interactions, _from, state) do
    {:reply, state.finished_interactions, %{state |
                         finished_interactions: [],
                         size: state.size - length(state.finished_interactions)}}
  end

  defp max_interactions do
    Application.get_env(:skope, :max_interactions_for_interval, 100)
  end
end
