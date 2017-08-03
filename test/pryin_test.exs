defmodule PryInTest do
  use PryIn.Case
  require PryIn.TestEndpoint
  alias PryIn.{CustomTrace, InteractionStore}

  describe "join_trace" do
    test "adds a child process to a parent trace" do
      CustomTrace.start(group: "workers", key: "daily_email_job")
      self_pid = self()
      task = Task.async(fn ->
        PryIn.join_trace(self_pid, self())
        PryIn.TestEndpoint.instrument :pryin, %{key: "expensive_api_call"}, fn ->
          :timer.sleep(1)
        end
      end)

      Task.await(task)
      CustomTrace.finish()

      [interaction] = InteractionStore.get_state.finished_interactions
      [custom_instrumentation] = interaction.custom_metrics
      assert custom_instrumentation.key == "expensive_api_call"
      assert custom_instrumentation.pid == inspect(task.pid)
    end

    test "does nothing if the child process is the same as the parent process" do
      CustomTrace.start(group: "workers", key: "daily_email_job")
      PryIn.join_trace(self(), self())
      PryIn.TestEndpoint.instrument :pryin, %{key: "expensive_api_call"}, fn ->
        :timer.sleep(1)
      end
      CustomTrace.finish()

      [interaction] = InteractionStore.get_state.finished_interactions
      [custom_instrumentation] = interaction.custom_metrics
      assert custom_instrumentation.key == "expensive_api_call"
      assert custom_instrumentation.pid == inspect(self())
    end

    test "does nothing if the child process already joined the parent trace" do
      CustomTrace.start(group: "workers", key: "daily_email_job")
      self_pid = self()
      task = Task.async(fn ->
        PryIn.join_trace(self_pid, self())
        PryIn.join_trace(self_pid, self())
        PryIn.TestEndpoint.instrument :pryin, %{key: "expensive_api_call"}, fn ->
          :timer.sleep(1)
        end
      end)

      Task.await(task)
      CustomTrace.finish()

      [interaction] = InteractionStore.get_state.finished_interactions
      [custom_instrumentation] = interaction.custom_metrics
      assert custom_instrumentation.key == "expensive_api_call"
      assert custom_instrumentation.pid == inspect(task.pid)
    end

    test "logs a warning when trying to join one parent trace to another" do
      CustomTrace.start(group: "workers", key: "daily_email_job")
      old_parent_pid = self()
      parent_task = Task.async(fn ->
        CustomTrace.start(group: "workers", key: "child_job")
        assert ExUnit.CaptureLog.capture_log([level: :warn], fn ->
          PryIn.join_trace(old_parent_pid, self())
          PryIn.InteractionStore.has_pid?(self()) # synchronize
        end) =~ "cannot join"
        CustomTrace.finish()
      end)
      Task.await(parent_task)
    end

    test "moves the child to a different trace if called with different parents" do
      CustomTrace.start(group: "workers", key: "daily_email_job")
      old_parent_pid = self()
      parent_task = Task.async(fn ->
        CustomTrace.start(group: "workers", key: "child_job")
        new_parent_pid = self()
        child_task = Task.async(fn ->
          PryIn.join_trace(old_parent_pid, self())
          PryIn.join_trace(new_parent_pid, self())
          PryIn.TestEndpoint.instrument :pryin, %{key: "expensive_api_call"}, fn ->
            :timer.sleep(1)
          end
        end)
        Task.await(child_task)
        CustomTrace.finish()
        {new_parent_pid, child_task.pid}
      end)

      {new_parent_pid, child_pid} = Task.await(parent_task)
      CustomTrace.finish()

      [interaction] = for interaction <- InteractionStore.get_state.finished_interactions,
        interaction.pid == inspect(new_parent_pid),
        do: interaction
      [custom_instrumentation] = interaction.custom_metrics
      assert custom_instrumentation.key == "expensive_api_call"
      assert custom_instrumentation.pid == inspect(child_pid)

      [old_interaction] = for interaction <- InteractionStore.get_state.finished_interactions,
        interaction.pid == inspect(old_parent_pid),
        do: interaction
      assert old_interaction.custom_metrics == []
    end

    test "logs a warning when the parent does not exist" do
      assert ExUnit.CaptureLog.capture_log([level: :warn], fn ->
        PryIn.join_trace(self(), self())
        PryIn.InteractionStore.has_pid?(self()) # synchronize
      end) =~ "cannot join trace"
    end

    test "allows finishing a parent transaction from the child process" do
      CustomTrace.start(group: "workers", key: "daily_email_job")
      self_pid = self()
      task = Task.async(fn ->
        PryIn.join_trace(self_pid, self())
        PryIn.TestEndpoint.instrument :pryin, %{key: "expensive_api_call"}, fn ->
          :timer.sleep(1)
        end
        CustomTrace.finish()
      end)
      Task.await(task)

      [interaction] = InteractionStore.get_state.finished_interactions
      [custom_instrumentation] = interaction.custom_metrics
      assert custom_instrumentation.key == "expensive_api_call"
      assert custom_instrumentation.pid == inspect(task.pid)
    end
  end

  describe "drop_trace" do
    test "drops a running interaction" do
      CustomTrace.start(group: "workers", key: "daily_email_job")
      PryIn.drop_trace()
      CustomTrace.finish()

      assert InteractionStore.get_state.finished_interactions == []
    end

    test "does not error when no trace is running" do
      PryIn.drop_trace()
    end
  end

  describe "put_context" do
    test "adds to the context of a running interaction" do
      CustomTrace.start(group: "workers", key: "daily_email_job")
      PryIn.put_context(:user_id, 123)
      assert InteractionStore.get_interaction(self()).context == [{"user_id", "123"}]
    end

    test "does not error when no trace is running" do
      PryIn.put_context(:user_id, 123)
    end
  end


end
