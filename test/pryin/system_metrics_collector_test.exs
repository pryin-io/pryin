defmodule PryIn.SystemMetricsCollectorTest do
  use PryIn.Case
  alias PryIn.{Data, SystemMetricsCollector}

  test "sends system metrics" do
    Application.put_env(:pryin, :collect_interval, 0)
    send(SystemMetricsCollector, :collect_metrics)
    assert_receive({:system_metrics_sent, encoded_data}, 500)
    data = Data.decode(encoded_data)
    assert data.env == :dev
    assert data.pryin_version == "1.4.0"
    assert data.app_version == "1.2.7" # otp_app ist set to :exprotobuf
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
    for {scheduler_index, scheduler_usage} <- data.system_metrics.scheduler_usage do
      assert is_number(scheduler_index)
      assert is_number(scheduler_usage)
    end
    assert is_number(data.system_metrics.time)
  end
end
