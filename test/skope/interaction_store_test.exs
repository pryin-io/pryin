defmodule Skope.InteractionStoreTest do
  use Skope.Case
  alias Skope.{InteractionStore, Interaction}

  setup _ do
    max_interactions = Application.get_env(:skope, :max_interactions_for_interval)

    on_exit fn ->
      Application.put_env(:skope, :max_interactions_for_interval, max_interactions)
    end
  end

  describe "start_interaction" do
    test "adds a running interaction" do
      interaction = %Interaction{duration: 1}
      InteractionStore.start_interaction(self, interaction)
      assert InteractionStore.get_state.running_interactions == %{self => interaction}
    end

    test "limits number of interactions" do
      Application.put_env(:skope, :max_interactions_for_interval, 2)
      interaction_1 = %Interaction{start_time: 1000, duration: 1}
      pid_1 = spawn fn -> :timer.sleep(5000) end
      interaction_2 = %Interaction{start_time: 1000, duration: 2}
      pid_2 = spawn fn -> :timer.sleep(5000) end
      interaction_3 = %Interaction{start_time: 1000, duration: 3}
      pid_3 = spawn fn -> :timer.sleep(5000) end

      InteractionStore.start_interaction(pid_1, interaction_1)
      assert InteractionStore.get_state.size == 1
      InteractionStore.start_interaction(pid_2, interaction_2)
      assert InteractionStore.get_state.size == 2
      InteractionStore.start_interaction(pid_3, interaction_3)
      assert InteractionStore.get_state.size == 2
      assert Map.keys(InteractionStore.get_state.running_interactions) == [pid_1, pid_2]

      InteractionStore.finish_interaction(pid_1)
      InteractionStore.start_interaction(pid_3, interaction_3)
      assert InteractionStore.get_state.size == 2
      assert Map.keys(InteractionStore.get_state.running_interactions) == [pid_2]
      assert InteractionStore.get_state.finished_interactions == [%{interaction_1 | start_time: 1}]
    end
  end

  test "set_interaction_data" do
    interaction = %Interaction{duration: 1}
    InteractionStore.start_interaction(self, interaction)
    InteractionStore.set_interaction_data(self, %{duration: 30})
    assert InteractionStore.get_state.running_interactions == %{self => %Interaction{duration: 30}}
  end

  test "add_extra_data" do
    interaction = %Interaction{}
    extra_data = %{some: :thing}
    InteractionStore.start_interaction(self, interaction)
    InteractionStore.add_extra_data(self, extra_data)
    assert InteractionStore.get_state.running_interactions == %{self => %Interaction{extra_data: [extra_data]}}
  end

  test "finish_request" do
    start_time_micros = 1000
    start_time_millis = 1
    interaction = %Interaction{start_time: start_time_micros}
    InteractionStore.start_interaction(self, interaction)
    InteractionStore.finish_interaction(self)
    assert InteractionStore.get_state.finished_interactions == [%{interaction | start_time: start_time_millis}]
    assert InteractionStore.get_state.running_interactions == %{}
  end

  test "handle DOWN for an interaction process" do
    interaction = %Interaction{duration: 1}
    pid = spawn fn -> :timer.sleep(5000) end
    InteractionStore.start_interaction(pid, interaction)
    assert InteractionStore.get_state.running_interactions == %{pid => interaction}
    assert InteractionStore.get_state.size == 1

    Process.exit(pid, :kill)
    wait_until_process_stopped(pid)
    assert InteractionStore.get_state.running_interactions == %{}
    assert InteractionStore.get_state.size == 0
  end

  test "has_pid" do
    interaction = %Interaction{start_time: 1000}
    pid = spawn fn -> :timer.sleep(5000) end
    refute InteractionStore.has_pid?(pid)

    InteractionStore.start_interaction(pid, interaction)
    assert InteractionStore.has_pid?(pid)

    InteractionStore.finish_interaction(pid)
    refute InteractionStore.has_pid?(pid)
  end

  test "get_field" do
    interaction = %Interaction{start_time: 1000}
    pid = spawn fn -> :timer.sleep(5000) end

    InteractionStore.start_interaction(pid, interaction)
    assert InteractionStore.get_field(pid, :start_time) == 1000
  end

  test "pop_finished_interactions" do
    interaction_1 = %Interaction{start_time: 1000}
    pid_1 = spawn fn -> :timer.sleep(5000) end
    interaction_2 = %Interaction{start_time: 1000}
    pid_2 = spawn fn -> :timer.sleep(5000) end

    InteractionStore.start_interaction(pid_1, interaction_1)
    InteractionStore.start_interaction(pid_2, interaction_2)
    InteractionStore.finish_interaction(pid_1)

    assert InteractionStore.pop_finished_interactions == [%{interaction_1 | start_time: 1}]
    assert InteractionStore.get_state.size == 1
    assert InteractionStore.get_state.finished_interactions == []
  end


  defp wait_until_process_stopped(pid) do
    timer_ref = Process.send_after(self, :stop_waiting_until_process_stopped, 1000)
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
