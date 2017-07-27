defmodule PryIn.EctoLogger do
  require Logger
  alias PryIn.{Wormhole, InteractionStore}
  import PryIn.TimeHelper

  @moduledoc """
  Collects metrics for ecto queries inside a tracked interaction.

  Activate via:

  ```elixir
  config :my_app, MyApp.Repo,
    loggers: [PryIn.EctoLogger, Ecto.LogEntry]
  ```

  """

  @doc false
  def log(log_entry) do
    parent_pid = self()
    Wormhole.capture fn ->
      pid = Map.get(log_entry, :connection_pid) || parent_pid
      do_log(log_entry, pid)
    end

    log_entry
  end

  defp do_log(log_entry, pid) do
    if InteractionStore.has_pid?(pid) do
      now = utc_unix_datetime()
      query_time = process_time(log_entry.query_time)
      decode_time = process_time(log_entry.decode_time)
      queue_time = process_time(log_entry.queue_time)
      duration = query_time + decode_time + queue_time

      data = [
        query: resolve_query(log_entry.query),
        query_time: query_time,
        decode_time: decode_time,
        queue_time: queue_time,
        source: Map.get(log_entry, :source),
        duration: duration,
        offset: now - InteractionStore.get_field(pid, :start_time) - duration,
        pid: inspect(pid)
      ]

      InteractionStore.add_ecto_query(pid, data)
    end
  end

  defp process_time(nil), do: 0
  defp process_time(time) do
    System.convert_time_unit(time, :native, :micro_seconds)
  end

  defp resolve_query(query, entry) when is_function(query), do: query.(entry)
  defp resolve_query(query, _entry), do: query
end
