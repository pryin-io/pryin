defmodule PryIn.CustomTraceTest do
  use PryIn.Case
  alias PryIn.{InteractionStore, CustomTrace}

  test "generates a custom trace" do
    CustomTrace.start(group: "workers", key: "daily_email_job")
    CustomTrace.finish()

    [interaction] = InteractionStore.get_state.finished_interactions
    assert interaction.start_time
    assert interaction.duration
    assert interaction.type == :custom_trace
    assert interaction.custom_group == "workers"
    assert interaction.custom_key == "daily_email_job"
    assert interaction.pid == inspect(self())
  end

  test "supports rate sampling" do
    Application.put_env(:pryin, :max_interactions_for_interval, 1000)
    for _ <- 0..1000 do
      CustomTrace.start(group: "workers", key: "daily_email_job", sample_rate: 0.5)
      CustomTrace.finish()
    end

    interaction_length = length(InteractionStore.get_state.finished_interactions)
    assert interaction_length > 300
    assert interaction_length < 700
  end

  test "can set group and key on trace start" do
    CustomTrace.start()
    CustomTrace.set_group("workers")
    CustomTrace.set_key("daily_email_job")
    CustomTrace.finish()

    [interaction] = InteractionStore.get_state.finished_interactions
    assert interaction.custom_group == "workers"
    assert interaction.custom_key == "daily_email_job"
  end

  test "can overwrite group and key later" do
    CustomTrace.start(group: "graphql", key: "all_users_query")
    CustomTrace.set_group("workers")
    CustomTrace.set_key("daily_email_job")
    CustomTrace.finish()

    [interaction] = InteractionStore.get_state.finished_interactions
    assert interaction.custom_group == "workers"
    assert interaction.custom_key == "daily_email_job"
  end

  test "does not fail if pryin is not running" do
    ref = Process.monitor(InteractionStore)
    Application.stop(:pryin)
    assert_receive {:DOWN, ^ref, _, _, _}

    CustomTrace.start()
    CustomTrace.set_group("workers")
    CustomTrace.set_key("daily_email_job")
    CustomTrace.finish()

    {:ok, _} = Application.ensure_all_started(:pryin)
  end

end
