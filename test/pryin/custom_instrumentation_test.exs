defmodule PryIn.CustomInstrumentationTest do
  use PryIn.Case
  alias PryIn.{CustomInstrumentation, InteractionStore}


  @env %Macro.Env{
    module: PryIn.TestController,
    function: "custom_instrumentation_action/2",
    file: "test/support/test_controller.ex",
    line: 123
  }

  test "custom instrumentation whithin a running trace" do
    PryIn.CustomTrace.start(group: "test", key: "test")
    data = CustomInstrumentation.start("expensive_api_call", @env)
    CustomInstrumentation.finish(5000, data)
    PryIn.CustomTrace.finish()

    [interaction] = InteractionStore.get_state.finished_interactions
    [custom_instrumentation] = interaction.custom_metrics

    assert custom_instrumentation.offset > 0
    assert custom_instrumentation.duration == 5
    assert custom_instrumentation.key == "expensive_api_call"
    assert custom_instrumentation.file =~ "test/support/test_controller.ex"
    assert custom_instrumentation.function == "custom_instrumentation_action/2"
    assert custom_instrumentation.module == "PryIn.TestController"
    assert custom_instrumentation.line == 123
    assert custom_instrumentation.pid == inspect(self())
  end

  test "custom instrumentation outside of a interaction" do
    ref = Process.monitor(PryIn.InteractionStore)

    data = CustomInstrumentation.start("expensive_api_call", @env)
    CustomInstrumentation.finish(5000, data)

    refute_receive({:DOWN, ^ref, _, _, _})
  end

  test "custom instrumentation when the interaction is finished inside" do
    ref = Process.monitor(PryIn.InteractionStore)

    PryIn.CustomTrace.start(group: "test", key: "test")
    data = CustomInstrumentation.start("expensive_api_call", @env)
    PryIn.CustomTrace.finish()
    CustomInstrumentation.finish(5000, data)

    refute_receive({:DOWN, ^ref, _, _, _})
  end
end
