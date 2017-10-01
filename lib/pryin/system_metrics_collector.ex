defmodule PryIn.SystemMetricsCollector do
  use GenServer
  require Logger
  alias PryIn.{SystemMetrics, BaseForwarder}

  @moduledoc false


  # CLIENT

  @doc false
  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end


  # SERVER
  def init(state) do
    loop_collect_system_metrics()
    {:ok, state}
  end

  def handle_info(:collect_metrics, state) do
    :recon.node_stats_list(1, collect_interval_millis())
    |> parse_metrics()
    |> forward_metrics()

    loop_collect_system_metrics()
    {:noreply, state}
  end

  @lint {Credo.Check.Refactor.ABCSize, false}
  defp parse_metrics([{absolutes, increments}]) do
    SystemMetrics.new(
      process_count: absolutes[:process_count],
      run_queue: absolutes[:run_queue],
      error_logger_queue_len: absolutes[:error_logger_queue_len],
      memory_total: absolutes[:memory_total],
      memory_procs: absolutes[:memory_procs],
      memory_atoms: absolutes[:memory_atoms],
      memory_bin: absolutes[:memory_bin],
      memory_ets: absolutes[:memory_ets],
      bytes_in: increments[:bytes_in],
      bytes_out: increments[:bytes_out],
      gc_count: increments[:gc_count],
      gc_words_reclaimed: increments[:gc_words_reclaimed],
      reductions: increments[:reductions],
      scheduler_usage: parse_scheduler_usage(increments[:scheduler_usage]),
      time: DateTime.utc_now |> DateTime.to_unix(:milliseconds),
    )
  end
  _ = @lint

  defp forward_metrics(system_metrics) do
    [system_metrics: system_metrics]
    |> BaseForwarder.wrap_data()
    |> BaseForwarder.api().send_system_metrics
  end

  defp parse_scheduler_usage(scheduler_usage) do
    for {scheduler_index, wall_time_diff} <- scheduler_usage do
      SystemMetrics.SchedulerUsage.new(
        scheduler_index: scheduler_index,
        wall_time_diff: wall_time_diff
      )
    end
  end

  defp collect_interval_millis do
    Application.get_env(:pryin, :collect_interval, 60_000)
  end

  defp loop_collect_system_metrics do
    if Application.get_env(:pryin, :collect_system_metrics, true) do
      send(self(), :collect_metrics)
    end
  end
end
