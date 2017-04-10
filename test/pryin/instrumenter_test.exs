defmodule PryIn.InstrumenterTest do
  use PryIn.Case
  use Phoenix.ConnTest
  alias Phoenix.ChannelTest
  require ChannelTest
  require PryIn.TestEndpoint
  alias PryIn.InteractionStore

  @endpoint PryIn.TestEndpoint

  setup _ do
    PryIn.TestEndpoint.start_link
    conn = build_conn()
    {:ok, conn: conn}
  end

  test "view rendering instrumentation", %{conn: conn} do
    get conn, "/render_test"

    [interaction] = InteractionStore.get_state.finished_interactions
    [view_rendering] = interaction.view_renderings

    assert view_rendering.offset > 0
    assert view_rendering.duration > 0
    assert view_rendering.format == "html"
    assert view_rendering.template == "test_template.html"
  end


  test "custom instrumentation whithin a interaction", %{conn: conn} do
    get conn, "/custom_instrumentation"

    [interaction] = InteractionStore.get_state.finished_interactions
    [custom_instrumentation] = interaction.custom_metrics

    assert custom_instrumentation.offset > 0
    assert custom_instrumentation.duration > 0
    assert custom_instrumentation.key == "expensive_api_call"
    assert custom_instrumentation.file =~ "test/support/test_controller.ex"
    assert custom_instrumentation.function == "custom_instrumentation_action/2"
    assert custom_instrumentation.module == "PryIn.TestController"
    assert custom_instrumentation.line > 0
  end


  test "custom instrumentation outside of a interaction" do
    assert ExUnit.CaptureLog.capture_log(fn ->
      PryIn.TestEndpoint.instrument :pryin, %{key: "expensive_api_call"}, fn ->
        :timer.sleep(1)
      end
    end) == ""
  end

  test "channel handle_in instrumentation" do
    {:ok, socket} = ChannelTest.connect(PryIn.TestSocket, %{})
    {:ok, _, socket} = ChannelTest.subscribe_and_join(socket, "test:topic", %{})
    ref = ChannelTest.push(socket, "test:msg", %{})
    ChannelTest.assert_reply ref, :ok

    wait_until fn ->
      [interaction] = InteractionStore.get_state.finished_interactions
      assert interaction.type           == :channel_receive
      assert interaction.interaction_id != nil
      assert interaction.channel        == "PryIn.TestChannel"
      assert interaction.topic          == "test:topic"
      assert interaction.event          == "test:msg"
      assert interaction.start_time     != nil
      assert interaction.duration       != nil
    end
  end

  defp wait_until(predicate_fn) do
    timer_ref = Process.send_after(self(), :stop_waiting_until, 1000)
    do_wait_until(predicate_fn, timer_ref)
  end
  defp do_wait_until(predicate_fn, timer_ref) do
    receive do
      :stop_waiting_until -> raise "timeout waiting"
    after 0 ->
      try do
        predicate_fn.()
        Process.cancel_timer(timer_ref)
      rescue
        [ExUnit.AssertionError, MatchError] -> do_wait_until(predicate_fn, timer_ref)
      end
    end
  end
end
