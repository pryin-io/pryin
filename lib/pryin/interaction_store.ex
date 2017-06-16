defmodule PryIn.InteractionStore do
  use GenServer
  require Logger
  defstruct [running_interactions: %{}, finished_interactions: []]
  alias PryIn.{Wormhole, Interaction}

  defmodule RunningInteraction do
    @moduledoc """
    Data about a single running interaction
    """

    defstruct [:type, :interaction, :ref, :child_pids, :parent_pid]
  end

  @moduledoc """
  Stores interactions that will later be forwarded by the forwarder.

  When a certain amount of interactions is in the store,
  further interactions will simply be dropped to avoid overflow.

  When the stored interactions are forwarded,
  the internal list is cleared and the limit is reset.

  This amount can be configured with:
  `config :pryin, :max_interactions_for_interval, 100`
  """

  # CLIENT

  @doc false
  def start_link() do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  @doc """
  Start an interaction.

  Adds an interaction - identified by a pid - to the internal interactions list.
  """
  def start_interaction(pid, interaction) do
    GenServer.cast(__MODULE__, {:start_interaction, pid, interaction})
  end

  @doc """
  Updates a running interactions data.
  """
  def set_interaction_data(pid, data) do
    GenServer.cast(__MODULE__, {:set_interaction_data, pid, data})
  end

  @doc """
  Adds ecto query data to a running interaction.
  """
  def add_ecto_query(pid, data) do
    GenServer.cast(__MODULE__, {:add_ecto_query, pid, data})
  end

  @doc """
  Adds view rendering data to a running interaction.
  """
  def add_view_rendering(pid, data) do
    GenServer.cast(__MODULE__, {:add_view_rendering, pid, data})
  end

  @doc """
  Adds custom metric data to a running interaction.
  """
  def add_custom_metric(pid, data) do
    GenServer.cast(__MODULE__, {:add_custom_metric, pid, data})
  end

  @doc """
  Finishes a running interaction.

  Finished interactions are moved from the running interactions list
  to the finished interactions list.
  They still count towards the `max_interactions_for_interval` limit.
  When the `InteractionForwarder` polls for interactions, only finished ones are
  returned.
  If the interaction is a request and has neither controller nor action set, it
  is dropped.
  """
  def finish_interaction(pid) do
    GenServer.cast(__MODULE__, {:finish_interaction, pid})
  end

  @doc """
  Returns whether there is a running interaction for the given `pid`.
  """
  def has_pid?(pid) do
    result = Wormhole.capture fn ->
      if Process.whereis(__MODULE__) do
        GenServer.call(__MODULE__, {:has_pid, pid})
      end
    end

    case result do
      {:ok, true_or_false} -> true_or_false
      _ -> false
    end
  end

  @doc """
  Returns the `field` value of the running interaction with the given `pid`.
  Not save to call. Wrap in `Wormhole.capture`.
  """
  def get_field(pid, field) do
    GenServer.call(__MODULE__, {:get_field, pid, field})
  end

  @doc """
  Returns and clears the list of running interactions.

  Called by the forwarder.
  """
  def pop_finished_interactions do
    GenServer.call(__MODULE__, :pop_finished_interactions)
  end


  @doc """
  Adds a child process to a running interaction.

  Should not be used directly. Use `PryIn.join_trace/2` instead.
  """
  def add_child(parent_pid, child_pid) do
    GenServer.cast(__MODULE__, {:add_child, parent_pid, child_pid})
  end

  # for testing

  @doc false
  def get_interaction(pid) do
    GenServer.call(__MODULE__, {:get_interaction, pid})
  end

  @doc false
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc false
  def reset_state do
    GenServer.call(__MODULE__, :reset_state)
  end


  # SERVER

  def handle_cast({:start_interaction, pid, interaction}, state) do
    state = drop_running_interaction(pid, state)

    if stored_interactions_count(state) >= max_interactions() do
      Logger.info("[PryIn] Dropping interaction #{inspect pid} because buffer is full.")
      {:noreply, state}
    else
      ref = Process.monitor(pid)
      running_interaction = %RunningInteraction{type: :parent, interaction: interaction, ref: ref, child_pids: MapSet.new}
      running_interactions = Map.put(state.running_interactions, pid, running_interaction)
      {:noreply, %{state | running_interactions: running_interactions}}
    end
  end

  def handle_cast({:set_interaction_data, pid, data}, state) do
    state = update_in(state.running_interactions[parent_pid(state, pid)].interaction,
      fn interaction -> Map.merge(interaction, data)
    end)
    {:noreply, state}
  end

  def handle_cast({:add_ecto_query, pid, data}, state) do
    state = update_in(state.running_interactions[parent_pid(state, pid)].interaction,
      fn
        nil -> nil
        interaction ->
          ecto_query = Interaction.EctoQuery.new(data)
          Map.update!(interaction, :ecto_queries, &([ecto_query | &1]))
      end)
    {:noreply, state}
  end

  def handle_cast({:add_view_rendering, pid, data}, state) do
    state = update_in(state.running_interactions[parent_pid(state, pid)].interaction,
      fn
        nil -> nil
        interaction ->
          view_rendering = Interaction.ViewRendering.new(data)
          Map.update!(interaction, :view_renderings, &([view_rendering | &1]))
      end)
    {:noreply, state}
  end

  def handle_cast({:add_custom_metric, pid, data}, state) do
    state = update_in(state.running_interactions[parent_pid(state, pid)].interaction,
      fn
        nil -> nil
        interaction ->
          custom_metric = Interaction.CustomMetric.new(data)
          Map.update!(interaction, :custom_metrics, &([custom_metric | &1]))
      end)
    {:noreply, state}
  end

  def handle_cast({:finish_interaction, pid}, state) do
    {finished_running_interaction, running_interactions} =
      Map.pop(state.running_interactions, parent_pid(state, pid))
    Process.demonitor(finished_running_interaction.ref)

    running_interactions = clear_children(running_interactions, finished_running_interaction.child_pids)

    finished_interaction = Map.update!(finished_running_interaction.interaction, :start_time, &trunc(&1 / 1000))

    if forward_interaction?(finished_interaction) do
      Logger.debug("[PryIn] Finished interaction: #{finished_interaction.interaction_id}")
      {:noreply, %{state |
                   running_interactions: running_interactions,
                   finished_interactions: [finished_interaction | state.finished_interactions]}}
    else
      Logger.debug("[PryIn] dropped interaction without controller, action and custom key: #{finished_interaction.interaction_id}")
      {:noreply, %{state |
                   running_interactions: running_interactions,
                   finished_interactions: state.finished_interactions}}
    end
  end

  def handle_cast({:add_child, parent_pid, child_pid}, state) do
    state = if state.running_interactions[parent_pid] do
      case state.running_interactions[child_pid] do
        nil -> add_new_child(state, parent_pid, child_pid)
        %RunningInteraction{type: :parent} when child_pid == parent_pid -> state
        %RunningInteraction{type: :parent} ->
          Logger.warn("[PryIn] cannot join #{inspect child_pid} to a different join, because it is already running a trace")
          state
        _running_interaction -> move_child_to_new_parent(state, parent_pid, child_pid)
      end
    else
      Logger.warn("[PryIn] cannot join trace #{inspect parent_pid}, because it is not running")
      state
    end
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    Logger.debug("[PryIn] Interaction process down before finish was called")

    {:noreply, drop_running_interaction(pid, state)}
  end

  def handle_call({:has_pid, pid}, _from, state) do
    result = pid in Map.keys(state.running_interactions)
    {:reply, result, state}
  end

  def handle_call({:get_field, pid, field}, _from, state) do
    result = Map.get(state.running_interactions[parent_pid(state, pid)].interaction, field)
    {:reply, result, state}
  end

  def handle_call({:get_interaction, pid}, _from, state) do
    interaction = state.running_interactions[parent_pid(state, pid)].interaction
    {:reply, interaction, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:reset_state, _from, _state) do
    {:reply, :ok, %__MODULE__{}}
  end

  def handle_call(:pop_finished_interactions, _from, state) do
    {:reply, state.finished_interactions, %{state | finished_interactions: []}}
  end

  defp max_interactions do
    Application.get_env(:pryin, :max_interactions_for_interval, 100)
  end

  defp forward_interaction?(interaction = %{type: :request}) do
    interaction.controller || interaction.action
  end
  defp forward_interaction?(%{type: :channel_receive}), do: true
  defp forward_interaction?(%{type: :channel_join}), do: true
  defp forward_interaction?(interaction = %{type: :custom_trace}) do
    interaction.custom_group && interaction.custom_key
  end

  defp stored_interactions_count(%{finished_interactions: finished_interactions, running_interactions: running_interactions}) do
    Enum.count(running_interactions, fn {_pid, interaction} -> (interaction.type == :parent) end) + length(finished_interactions)
  end

  defp drop_running_interaction(pid, state) do
    {down_running_interaction, running_interactions} = Map.pop(state.running_interactions, pid)
    running_interactions = case down_running_interaction do
                             nil -> running_interactions
                             %RunningInteraction{type: :parent} ->
                               Process.demonitor(down_running_interaction.ref)
                               clear_children(running_interactions, down_running_interaction.child_pids)
                             %RunningInteraction{type: :child} ->
                               Process.demonitor(down_running_interaction.ref)
                               update_in(running_interactions[down_running_interaction.parent_pid].child_pids, fn child_pids ->
                                 MapSet.delete(child_pids, pid)
                               end)
                           end

    %{state | running_interactions: running_interactions}
  end

  defp clear_children(running_interactions, nil), do: running_interactions
  defp clear_children(running_interactions, child_pids) do
    children = Map.take(running_interactions, child_pids) |> Map.values
    for child <- children, do: Process.demonitor(child.ref)
    Map.drop(running_interactions, child_pids)
  end

  defp parent_pid(state, child_pid) do
    case state.running_interactions[child_pid] do
      %RunningInteraction{type: :parent} -> child_pid
      %RunningInteraction{type: :child, parent_pid: pid} -> pid
    end
  end

  defp add_new_child(state, parent_pid, child_pid) do
    ref = Process.monitor(child_pid)
    running_interaction = %RunningInteraction{type: :child, ref: ref, parent_pid: parent_pid}
    running_interactions = Map.put(state.running_interactions, child_pid, running_interaction)

    running_interactions = update_in(running_interactions[parent_pid].child_pids, &MapSet.put(&1, child_pid))
    %{state | running_interactions: running_interactions}
  end

  def move_child_to_new_parent(state, parent_pid, child_pid) do
    child_interaction = state.running_interactions[child_pid]
    state = update_in(state.running_interactions[child_interaction.parent_pid].child_pids, fn child_pids ->
      MapSet.delete(child_pids, child_pid)
    end)
    state = update_in(state.running_interactions[parent_pid].child_pids, &MapSet.put(&1, child_pid))
    put_in(state.running_interactions[child_pid].parent_pid, parent_pid)
  end
end
