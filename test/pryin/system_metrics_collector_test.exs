defmodule PryIn.SystemMetricsCollectorTest do
  use PryIn.Case
  alias PryIn.{Data, SystemMetricsCollector}

  test "sends system metrics" do
    Application.put_env(:pryin, :collect_interval, 100)

    send(SystemMetricsCollector, :collect_metrics)

    assert_receive({:system_metrics_sent, encoded_data}, 200)

    data = Data.decode(encoded_data)

    assert data.env == :dev
    assert data.pryin_version == "1.5.2"
    # otp_app ist set to :exprotobuf
    assert data.app_version == "1.2.9"
    assert data.node_name == "nonode@nohost"
    assert is_number(data.system_metrics.process_count)
    assert is_number(data.system_metrics.run_queue)
    assert is_number(data.system_metrics.error_logger_queue_len)
    assert is_number(data.system_metrics.memory_total)
    assert is_number(data.system_metrics.memory_procs)
    assert is_number(data.system_metrics.memory_atoms)
    assert is_number(data.system_metrics.memory_bin)
    assert is_number(data.system_metrics.memory_ets)
    assert is_number(data.system_metrics.bytes_in)
    assert is_number(data.system_metrics.bytes_out)
    assert is_number(data.system_metrics.gc_count)
    assert is_number(data.system_metrics.gc_words_reclaimed)
    assert is_number(data.system_metrics.reductions)

    assert length(data.system_metrics.scheduler_usage) > 0

    for %PryIn.SystemMetrics.SchedulerUsage{
          scheduler_index: scheduler_index,
          wall_time_diff: wall_time_diff
        } <- data.system_metrics.scheduler_usage do
      assert is_number(scheduler_index)
      assert is_number(wall_time_diff)
    end

    assert is_number(data.system_metrics.time)
  end

  test "doesn't fail when the scheduler_wall_time flag is false" do
    Application.put_env(:pryin, :collect_interval, 500)
    :timer.apply_interval(1, :erlang, :system_flag, [:scheduler_wall_time, false])
    send(SystemMetricsCollector, :collect_metrics)

    assert_receive({:system_metrics_sent, encoded_data}, 1000)
    data = Data.decode(encoded_data)
    # can't really test for anything usefull here, except no error being raised.
    # setting the system flag only works sometimes.
    assert data.system_metrics.scheduler_usage
  end

  test "users can set a custom node name" do
    Application.put_env(:pryin, :collect_interval, 0)
    Application.put_env(:pryin, :node_name, "myapp@myhost")
    send(SystemMetricsCollector, :collect_metrics)
    assert_receive({:system_metrics_sent, encoded_data}, 500)
    data = Data.decode(encoded_data)
    assert data.node_name == "myapp@myhost"
    Application.delete_env(:pryin, :node_name)
  end
end
