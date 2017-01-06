defmodule PryIn.InstrumenterTest do
  use PryIn.Case
  use Phoenix.ConnTest
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
    view_rendering = interaction.extra_data
    |> Enum.find(& &1.type == "view_rendering")

    assert view_rendering.offset > 0
    assert view_rendering.duration > 0
    assert view_rendering.format == "html"
    assert view_rendering.template == "test_template.html"
  end


  test "custom instrumentation whithin a interaction", %{conn: conn} do
    get conn, "/custom_instrumentation"

    [interaction] = InteractionStore.get_state.finished_interactions
    custom_instrumentation = interaction.extra_data
    |> Enum.find(& &1.type == "custom_metric")

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
end
