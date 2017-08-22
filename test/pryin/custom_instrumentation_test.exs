defmodule PryIn.CustomInstrumentationTest do
  use PryIn.Case
  alias PryIn.{CustomInstrumentation, InteractionStore}


  @env %Macro.Env{
    module: PryIn.TestController,
    function: {:"custom_instrumentation_action", 2},
    file: "test/support/test_controller.ex",
    line: 123
  }

  property "custom instrumentation whithin a running trace adds a custom metric" do
    check all module_name <- PropertyHelpers.string(),
      function_name <- PropertyHelpers.string(),
      function_arrity <- int(0..255), # functions can have max 255 arguments
      file <- PropertyHelpers.string(),
      line <- PropertyHelpers.positive_int(),
      key <- PropertyHelpers.string(),
      duration <- int(0..10_000) do

      env = %Macro.Env{
        module: String.to_atom(module_name),
        function: {String.to_atom(function_name), function_arrity},
        file: file,
        line: line
      }

      InteractionStore.reset_state()
      PryIn.CustomTrace.start(group: "test", key: "test")
      data = CustomInstrumentation.start(key, env)
      CustomInstrumentation.finish(duration, data)
      PryIn.CustomTrace.finish()

      [interaction] = InteractionStore.get_state.finished_interactions
      [custom_instrumentation] = interaction.custom_metrics

      assert custom_instrumentation.offset > 0
      assert custom_instrumentation.duration == trunc(duration / 1000)
      assert custom_instrumentation.key == key
      assert custom_instrumentation.file =~ file
      assert custom_instrumentation.function == "#{function_name}/#{function_arrity}"
      assert custom_instrumentation.module == inspect(env.module)
      assert custom_instrumentation.line == line
      assert custom_instrumentation.pid == inspect(self())
    end
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
