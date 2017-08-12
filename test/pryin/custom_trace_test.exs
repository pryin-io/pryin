defmodule PryIn.CustomTraceTest do
  use PryIn.Case
  alias PryIn.{InteractionStore, CustomTrace}

  property "generates a custom trace" do
    check all group <- PropertyHelpers.non_empty_string(),
      key <- PropertyHelpers.non_empty_string() do
      InteractionStore.reset_state()
      CustomTrace.start(group: group, key: key)
      CustomTrace.finish()

      [interaction] = InteractionStore.get_state.finished_interactions
      assert interaction.start_time
      assert interaction.duration
      assert interaction.type == :custom_trace
      assert interaction.custom_group == group
      assert interaction.custom_key == key
      assert interaction.pid == inspect(self())
    end
  end

  property "can set group and key on trace start" do
    check all group <- PropertyHelpers.non_empty_string(),
    key <- PropertyHelpers.non_empty_string() do
      InteractionStore.reset_state()
      CustomTrace.start()
      CustomTrace.set_group(group)
      CustomTrace.set_key(key)
      CustomTrace.finish()

      [interaction] = InteractionStore.get_state.finished_interactions
      assert interaction.custom_group == group
      assert interaction.custom_key == key
    end
  end

  property "can overwrite group and key later" do
    check all old_group <- PropertyHelpers.non_empty_string(),
      old_key <- PropertyHelpers.non_empty_string(),
      new_group <- PropertyHelpers.non_empty_string(),
      new_key <- PropertyHelpers.non_empty_string() do
      InteractionStore.reset_state()
      CustomTrace.start(group: old_group, key: old_key)
      CustomTrace.set_group(new_group)
      CustomTrace.set_key(new_key)
      CustomTrace.finish()

      [interaction] = InteractionStore.get_state.finished_interactions
      assert interaction.custom_group == new_group
      assert interaction.custom_key == new_key
    end
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
