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
      pid = self()
      assert %{^pid => %{interaction: ^interaction}} = InteractionStore.get_state.running_interactions
    end

    property "limits number of interactions" do
      check all max_interactions <- int(1..500) do
        InteractionStore.reset_state()
        Application.put_env(:pryin, :max_interactions_for_interval, max_interactions)
        pids_with_interactions = for _ <- 1..max_interactions do
          interaction = Factory.build(:request, start_time: 1000, duration: 1, controller: "SomeController")
          pid = spawn fn -> :timer.sleep(5000) end
          InteractionStore.start_interaction(pid, interaction)
          {pid, interaction}
        end

        interaction = Factory.build(:request, start_time: 1000, duration: 1, controller: "SomeController")
        pid = spawn fn -> :timer.sleep(5000) end
        InteractionStore.start_interaction(pid, interaction)

        assert Map.keys(InteractionStore.get_state.running_interactions) |> Enum.sort() ==
          Enum.map(pids_with_interactions, &elem(&1, 0)) |> Enum.sort()

        [{pid_1, interaction_1} | remaining_pids_with_interactions] = pids_with_interactions
        InteractionStore.finish_interaction(pid_1)
        InteractionStore.start_interaction(pid, interaction)
        assert Map.keys(InteractionStore.get_state.running_interactions) |> Enum.sort() ==
          Enum.map(remaining_pids_with_interactions, &elem(&1, 0)) |> Enum.sort()
        assert InteractionStore.get_state.finished_interactions == [%{interaction_1 | start_time: 1}]
        Application.put_env(:pryin, :max_interactions_for_interval, 100)
      end
    end
  end

  test "set_interaction_data" do
    interaction = Factory.build(:request, duration: 1)
    InteractionStore.start_interaction(self(), interaction)
    InteractionStore.set_interaction_data(self(), %{duration: 30})
    pid = self()
    new_interaction = %{interaction | duration: 30}
    assert  %{^pid => %{interaction: ^new_interaction}} = InteractionStore.get_state.running_interactions
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


  property "finish_interaction with controller and action" do
    check all controller <- PropertyHelpers.non_empty_string(),
      action <- PropertyHelpers.non_empty_string(),
      start_time_millis <- int(1..100_000) do

      InteractionStore.reset_state()
      start_time_micros = start_time_millis * 1000

      interaction = Factory.build(:request, start_time: start_time_micros)
      InteractionStore.start_interaction(self(), interaction)
      InteractionStore.set_interaction_data(self(), %{controller: controller, action: action})
      InteractionStore.finish_interaction(self())
      assert InteractionStore.get_state.finished_interactions == [%{interaction | controller: controller,
                                                                    action: action,
                                                                    start_time: start_time_millis}]
      assert InteractionStore.get_state.running_interactions == %{}
    end
  end

  test "finish_interaction drops a request without controller" do
    interaction = Factory.build(:request, controller: nil)
    InteractionStore.start_interaction(self(), interaction)
    InteractionStore.finish_interaction(self())
    assert InteractionStore.get_state.finished_interactions == []
    assert InteractionStore.get_state.running_interactions == %{}

    interaction = Factory.build(:request, controller: "")
    InteractionStore.start_interaction(self(), interaction)
    InteractionStore.finish_interaction(self())
    assert InteractionStore.get_state.finished_interactions == []
    assert InteractionStore.get_state.running_interactions == %{}
  end

  test "finish_interaction drops a request without action" do
    interaction = Factory.build(:request, action: nil)
    InteractionStore.start_interaction(self(), interaction)
    InteractionStore.finish_interaction(self())
    assert InteractionStore.get_state.finished_interactions == []
    assert InteractionStore.get_state.running_interactions == %{}

    interaction = Factory.build(:request, action: "")
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

  test "finish_interaction drops a custom trace without group and key" do
    interaction = Factory.build(:custom_trace, custom_group: nil)
    InteractionStore.start_interaction(self(), interaction)
    InteractionStore.finish_interaction(self())
    assert InteractionStore.get_state.finished_interactions == []
    assert InteractionStore.get_state.running_interactions == %{}

    interaction = Factory.build(:custom_trace, custom_group: "")
    InteractionStore.start_interaction(self(), interaction)
    InteractionStore.finish_interaction(self())
    assert InteractionStore.get_state.finished_interactions == []
    assert InteractionStore.get_state.running_interactions == %{}

    interaction = Factory.build(:custom_trace, custom_key: nil)
    InteractionStore.start_interaction(self(), interaction)
    InteractionStore.finish_interaction(self())
    assert InteractionStore.get_state.finished_interactions == []
    assert InteractionStore.get_state.running_interactions == %{}

    interaction = Factory.build(:custom_trace, custom_key: "")
    InteractionStore.start_interaction(self(), interaction)
    InteractionStore.finish_interaction(self())
    assert InteractionStore.get_state.finished_interactions == []
    assert InteractionStore.get_state.running_interactions == %{}

    interaction = Factory.build(:custom_trace)
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
    assert  %{^pid => %{interaction: ^interaction}} = InteractionStore.get_state.running_interactions

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

    ref = Process.monitor(InteractionStore)
    Application.stop(:pryin)
    assert_receive {:DOWN, ^ref, _, _, _}
    refute InteractionStore.has_pid?(pid)
    {:ok, _} = Application.ensure_all_started(:pryin)
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

  test "drop_interaction" do
    pid_1 = spawn fn -> :timer.sleep(5000) end
    interaction = Factory.build(:request, start_time: 1000)
    InteractionStore.start_interaction(pid_1, interaction)
    InteractionStore.drop_interaction(pid_1)
    refute InteractionStore.has_pid?(pid_1)

    pid_2 = spawn fn -> :timer.sleep(5000) end
    # no error when dropping non existant interaction
    InteractionStore.drop_interaction(pid_2)
  end

  test "put_context" do
    pid = spawn fn -> :timer.sleep(5000) end
    interaction = Factory.build(:request, start_time: 1000)
    InteractionStore.start_interaction(pid, interaction)
    InteractionStore.put_context(pid, :project_title, "My awesome project")
    InteractionStore.finish_interaction(pid)

    [finished_interaction] = InteractionStore.pop_finished_interactions
    assert finished_interaction.context == [{"project_title", "My awesome project"}]
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
