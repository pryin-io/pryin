defmodule PryIn.Instrumenter do
  alias PryIn.{InteractionStore, Interaction}
  import PryIn.{TimeHelper, InteractionHelper}

  @moduledoc false

  # Collects metrics about view rendering and allows for custom instrumentation

  # Activate via:

  # ```elixir
  # config :my_app, MyApp.Endpoint,
  #   instrumenters: [PryIn.Instrumenter]
  # ```

  # To instrument custom code, wrap it with the `instrument` macro:
  # ```elixir
  #   require MyApp.Endpoint
  #   MyApp.Endpoint.instrument :pryin, %{key: "expensive_api_call"}, fn ->
  #     ...
  #   end
  # ```

  # The `key` (`"expensive_api_call"`) is just a string that you can freely choose to
  # indentify the metric later in the UI.

  def phoenix_controller_render(:start, _compile_metadata, runtime_metadata) do
    if InteractionStore.has_pid?(self()) do
      now = utc_unix_datetime()
      offset = now - InteractionStore.get_field(self(), :start_time)
      Map.put(runtime_metadata, :offset, offset)
    else
      runtime_metadata
    end
  end

  def phoenix_controller_render(:stop, time_diff, %{
        format: format,
        template: template,
        offset: offset
      }) do
    if InteractionStore.has_pid?(self()) do
      data = [
        format: format,
        template: template,
        offset: offset,
        duration: System.convert_time_unit(time_diff, :native, :micro_seconds),
        pid: inspect(self())
      ]

      InteractionStore.add_view_rendering(self(), data)
    end
  end

  def phoenix_controller_render(:stop, _time_diff, _), do: :ok

  def phoenix_channel_receive(:start, _compile_metadata, runtime_metadata) do
    interaction =
      Interaction.new(
        start_time: utc_unix_datetime(),
        type: :channel_receive,
        interaction_id: generate_interaction_id(),
        channel: module_name(runtime_metadata[:socket].channel),
        topic: runtime_metadata[:socket].topic,
        event: runtime_metadata[:event],
        pid: inspect(self())
      )

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

  def phoenix_channel_join(:start, _compile_metadata, runtime_metadata) do
    interaction =
      Interaction.new(
        start_time: utc_unix_datetime(),
        type: :channel_join,
        interaction_id: generate_interaction_id(),
        channel: module_name(runtime_metadata[:socket].channel),
        topic: runtime_metadata[:socket].topic,
        pid: inspect(self())
      )

    InteractionStore.start_interaction(self(), interaction)
  end

  def phoenix_channel_join(:stop, time_diff, _metadata) do
    if InteractionStore.has_pid?(self()) do
      duration = System.convert_time_unit(time_diff, :native, :micro_seconds)
      interaction_metadata = %{duration: duration}
      InteractionStore.set_interaction_data(self(), interaction_metadata)
      InteractionStore.finish_interaction(self())
    end
  end

  def pryin(:start, compile_metadata, %{key: key}) do
    PryIn.CustomInstrumentation.start(key, compile_metadata)
  end

  def pryin(:stop, _time_diff, nil), do: :ok

  def pryin(:stop, time_diff, data) do
    PryIn.CustomInstrumentation.finish(time_diff, data)
  end
end
