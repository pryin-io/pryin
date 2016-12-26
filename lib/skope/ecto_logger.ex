defmodule Skope.EctoLogger do
  require Logger
  alias Skope.InteractionStore
  import Skope.TimeHelper

  @moduledoc """
  Collects metrics for ecto queries inside a tracked interaction.

  Activate via:

  ```elixir
  config :my_app, MyApp.Repo,
    loggers: [Skope.EctoLogger, Ecto.LogEntry]
  ```

  """

  @doc false
  def log(log_entry) do
    pid = self
    try do
      do_log(log_entry, pid)
    rescue
      e -> Logger.warn("[Skope.EctoLogger] Could not log ecto query: #{inspect e}")
    catch
      e -> Logger.warn("[Skope.EctoLogger] Could not log ecto query: #{inspect e}")
    end
    log_entry
  end

  defp do_log(log_entry, pid) do
    if InteractionStore.has_pid?(pid) do
      now = utc_unix_datetime

      data = %{
        type: "ecto_query",
        query: log_entry.query,
        query_time: process_time(log_entry.query_time),
        decode_time: process_time(log_entry.decode_time),
        queue_time: process_time(log_entry.queue_time),
        source: Map.get(log_entry, :source),
      }
      data = Map.put(data, :duration, data.query_time + data.decode_time + data.queue_time)
      data = Map.put(data, :offset, now - InteractionStore.get_field(pid, :start_time) - data.duration)
      InteractionStore.add_extra_data(pid, data)
    end
  end

  defp process_time(nil), do: 0
  defp process_time(time) do
    System.convert_time_unit(time, :native, :micro_seconds)
  end
end
