defmodule PryIn.Instrumenter do
  alias PryIn.{InteractionStore, Interaction}
  import PryIn.{TimeHelper, InteractionHelper}

  @moduledoc """
  Collects metrics about view rendering and allows for custom instrumentation

  Activate via:

  ```elixir
  config :my_app, MyApp.Endpoint,
    instrumenters: [PryIn.Instrumenter]
  ```

  To instrument custom code, wrap it with the `instrument` macro:
  ```elixir
    require MyApp.Endpoint
    MyApp.Endpoint.instrument :pryin, %{key: "expensive_api_call"}, fn ->
      ...
    end
  ```

  The `key` (`"expensive_api_call"`) is just a string that you can freely choose to
  indentify the metric later in the UI.

  """

  @doc """
  Collects metrics about Phoenix view rendering.

  Metrics are only collected inside of tracked interactions.
  """
  def phoenix_controller_render(:start, _compile_metadata, runtime_metadata) do
    if InteractionStore.has_pid?(self()) do
      now = utc_unix_datetime()
      offset = now - InteractionStore.get_field(self(), :start_time)
      Map.put(runtime_metadata, :offset, offset)
    else
      runtime_metadata
    end
  end
  def phoenix_controller_render(:stop, time_diff, %{format: format, template: template, offset: offset}) do
    data = [
      format: format,
      template: template,
      offset: offset,
      duration: System.convert_time_unit(time_diff, :native, :micro_seconds),
    ]
    InteractionStore.add_view_rendering(self(), data)
  end
  def phoenix_controller_render(:stop, _time_diff, _), do: :ok


  @doc """
  Collect metrics about channel `handle_in` calls.
  """
  def phoenix_channel_receive(:start, _compile_metadata, runtime_metadata) do
    interaction = Interaction.new(start_time: utc_unix_datetime(),
      type: :channel_receive,
      interaction_id: generate_interaction_id(),
      channel: module_name(runtime_metadata[:socket].channel),
      topic: runtime_metadata[:socket].topic,
      event: runtime_metadata[:event])
    InteractionStore.start_interaction(self(), interaction)
  end
  def phoenix_channel_receive(:stop, time_diff, _metadata) do
    if InteractionStore.has_pid?(self()) do
      duration = System.convert_time_unit(time_diff, :native, :micro_seconds)
      interaction_metadata = %{duration: duration}
      InteractionStore.set_interaction_data(self(), interaction_metadata)
      InteractionStore.finish_interaction(self())
    end
  end



  @doc """
  Collects metrics about custom functions.

  Wrap any code in an instrumented function to have it's runtime
  reported to PryIn.
  The `key` parameter will be present in the web ui, so you can
  identify the measurement.

  Note that you need to `require` your endpoint before calling
  the `instrument` macro.

  Metrics are only collected inside of tracked interactions.
  """
  def pryin(:start, compile_metadata, %{key: key}) do
    if InteractionStore.has_pid?(self()) do
      now = utc_unix_datetime()
      offset = now - InteractionStore.get_field(self(), :start_time)
      [key: key,
       offset: offset,
       file: compile_metadata.file,
       module: inspect(compile_metadata.module),
       function: compile_metadata.function,
       line: compile_metadata.line]
    end
  end
  def pryin(:stop, _time_diff, nil), do: :ok
  def pryin(:stop, time_diff, data) do
    duration = System.convert_time_unit(time_diff, :native, :micro_seconds)
    data = [{:duration, duration} | data]
    InteractionStore.add_custom_metric(self(), data)
  end
end
