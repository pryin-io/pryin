defmodule PryIn.InteractionStoreTest do
  use PryIn.Case
  alias PryIn.{InteractionStore, Interaction}

  setup _ do
    max_interactions = Application.get_env(:pryin, :max_interactions_for_interval)

    on_exit fn ->
      Application.put_env(:pryin, :max_interactions_for_interval, max_interactions)
    end
  end

  describe "start_interaction" do
    test "adds a running interaction" do
      interaction = Factory.build(:request, duration: 1)
      InteractionStore.start_interaction(self(), interaction)
      assert InteractionStore.get_state.running_interactions == %{self() => interaction}
    end

    test "limits number of interactions" do
      Application.put_env(:pryin, :max_interactions_for_interval, 2)
      interaction_1 = Factory.build(:request, start_time: 1000, duration: 1, controller: "SomeController")
      pid_1 = spawn fn -> :timer.sleep(5000) end
      interaction_2 = Factory.build(:request, start_time: 1000, duration: 2, controller: "SomeController")
      pid_2 = spawn fn -> :timer.sleep(5000) end
      interaction_3 = Factory.build(:request, start_time: 1000, duration: 3, controller: "SomeController")
      pid_3 = spawn fn -> :timer.sleep(5000) end

      InteractionStore.start_interaction(pid_1, interaction_1)
      InteractionStore.start_interaction(pid_2, interaction_2)
      InteractionStore.start_interaction(pid_3, interaction_3)
      assert Map.keys(InteractionStore.get_state.running_interactions) == [pid_1, pid_2]

      InteractionStore.finish_interaction(pid_1)
      InteractionStore.start_interaction(pid_3, interaction_3)
      assert Map.keys(InteractionStore.get_state.running_interactions) == [pid_2]
      assert InteractionStore.get_state.finished_interactions == [%{interaction_1 | start_time: 1}]
    end
  end

  test "set_interaction_data" do
    interaction = Factory.build(:request, duration: 1)
    InteractionStore.start_interaction(self(), interaction)
    InteractionStore.set_interaction_data(self(), %{duration: 30})
    assert InteractionStore.get_state.running_interactions == %{self() => %{interaction | duration: 30}}
  end

  test "add_ecto_query" do
    interaction = Factory.build(:request)
    ecto_query = [duration: 123]
    InteractionStore.start_interaction(self(), interaction)
    InteractionStore.add_ecto_query(self(), ecto_query)
    assert InteractionStore.get_interaction(self()).ecto_queries == [Interaction.EctoQuery.new(duration: 123)]
  end

  test "add_view_rendering" do
    interaction = Factory.build(:request)
    view_rendering = [duration: 123]
    InteractionStore.start_interaction(self(), interaction)
    InteractionStore.add_view_rendering(self(), view_rendering)
    assert InteractionStore.get_interaction(self()).view_renderings == [Interaction.ViewRendering.new(duration: 123)]
  end
  test "add_custom_metric" do
    interaction = Factory.build(:request)
    custom_metric = [duration: 123]
    InteractionStore.start_interaction(self(), interaction)
    InteractionStore.add_custom_metric(self(), custom_metric)
    assert InteractionStore.get_interaction(self()).custom_metrics == [Interaction.CustomMetric.new(duration: 123)]
  end


  test "finish_interaction with controller and action" do
    start_time_micros = 1000
    start_time_millis = 1
    interaction = Factory.build(:request, start_time: start_time_micros)
    InteractionStore.start_interaction(self(), interaction)
    InteractionStore.set_interaction_data(self(), %{controller: "SomeController", action: "some_action"})
    InteractionStore.finish_interaction(self())
    assert InteractionStore.get_state.finished_interactions == [%{interaction | controller: "SomeController",
                                                                  action: "some_action",
                                                                  start_time: start_time_millis}]
    assert InteractionStore.get_state.running_interactions == %{}
  end

  test "finish_interaction drops a request without controller and action" do
    interaction = Factory.build(:request, controller: nil, action: nil)
    InteractionStore.start_interaction(self(), interaction)
    InteractionStore.finish_interaction(self())
    assert InteractionStore.get_state.finished_interactions == []
    assert InteractionStore.get_state.running_interactions == %{}
  end

  test "finish_interaction does not drop a channel receive without controller and action" do
    interaction = Factory.build(:channel_receive)
    InteractionStore.start_interaction(self(), interaction)
    InteractionStore.finish_interaction(self())
    interaction_id = interaction.interaction_id
    assert [%{interaction_id: ^interaction_id}] = InteractionStore.get_state.finished_interactions
    assert InteractionStore.get_state.running_interactions == %{}
  end

  test "finish_interaction does not drop a channel join without controller and action" do
    interaction = Factory.build(:channel_join)
    InteractionStore.start_interaction(self(), interaction)
    InteractionStore.finish_interaction(self())
    interaction_id = interaction.interaction_id
    assert [%{interaction_id: ^interaction_id}] = InteractionStore.get_state.finished_interactions
    assert InteractionStore.get_state.running_interactions == %{}
  end

  test "handle DOWN for an interaction process" do
    interaction = Factory.build(:request, duration: 1)
    pid = spawn fn -> :timer.sleep(5000) end
    InteractionStore.start_interaction(pid, interaction)
    assert InteractionStore.get_state.running_interactions == %{pid => interaction}

    Process.exit(pid, :kill)
    wait_until_process_stopped(pid)
    assert InteractionStore.get_state.running_interactions == %{}
  end

  test "has_pid" do
    interaction = Factory.build(:request, start_time: 1000)
    pid = spawn fn -> :timer.sleep(5000) end
    refute InteractionStore.has_pid?(pid)

    InteractionStore.start_interaction(pid, interaction)
    assert InteractionStore.has_pid?(pid)

    InteractionStore.finish_interaction(pid)
    refute InteractionStore.has_pid?(pid)
  end

  test "get_field" do
    interaction = Factory.build(:request, start_time: 1000)
    pid = spawn fn -> :timer.sleep(5000) end

    InteractionStore.start_interaction(pid, interaction)
    assert InteractionStore.get_field(pid, :start_time) == 1000
  end

  test "pop_finished_interactions" do
    interaction_1 = Factory.build(:request, start_time: 1000)
    pid_1 = spawn fn -> :timer.sleep(5000) end
    interaction_2 = Factory.build(:request, start_time: 1000)
    pid_2 = spawn fn -> :timer.sleep(5000) end

    InteractionStore.start_interaction(pid_1, interaction_1)
    InteractionStore.start_interaction(pid_2, interaction_2)
    InteractionStore.finish_interaction(pid_1)

    assert InteractionStore.pop_finished_interactions == [%{interaction_1 | start_time: 1}]
    assert InteractionStore.get_state.finished_interactions == []
  end


  defp wait_until_process_stopped(pid) do
    timer_ref = Process.send_after(self(), :stop_waiting_until_process_stopped, 1000)
    do_wait_until_process_stopped(pid, timer_ref)
  end
  defp do_wait_until_process_stopped(pid, timer_ref) do
    receive do
      :stop_waiting_until_process_stopped -> raise "timeout waiting for process #{inspect pid} to stop"
    after 0 ->
      if Process.alive?(pid) do
        wait_until_process_stopped(pid)
      else
        Process.cancel_timer(timer_ref)
        :ok
      end
    end
  end
end
