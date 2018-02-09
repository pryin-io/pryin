defmodule PryIn.CustomInstrumentation do
  alias PryIn.{InteractionStore, TimeHelper}

  @moduledoc false

  def start(key, compile_metadata) do
    if InteractionStore.has_pid?(self()) do
      now = TimeHelper.utc_unix_datetime()
      offset = now - InteractionStore.get_field(self(), :start_time)

      [
        key: key,
        offset: offset,
        file: compile_metadata.file,
        module: inspect(compile_metadata.module),
        function: format_function(compile_metadata.function),
        line: compile_metadata.line,
        pid: inspect(self())
      ]
    end
  end

  def finish(time_diff, data) do
    if InteractionStore.has_pid?(self()) do
      duration = System.convert_time_unit(time_diff, :native, :micro_seconds)
      data = [{:duration, duration} | data]
      InteractionStore.add_custom_metric(self(), data)
    end
  end

  defp format_function({name, arity}) do
    to_string(name) <> "/" <> to_string(arity)
  end

  defp format_function(name) when is_binary(name), do: name
  defp format_function(name), do: inspect(name)
end
