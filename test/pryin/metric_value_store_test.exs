defmodule PryIn.MetricValueStoreTest do
  use PryIn.Case
  alias PryIn.MetricValueStore

  test "add_metric_value" do
    MetricValueStore.add_metric_value("some label", 111, 222, %{})
    [metric_value] = MetricValueStore.pop_metric_values()
    assert metric_value.label == "some label"
    assert metric_value.value == 111
    assert metric_value.start_time == 222
    assert metric_value.context == []

    MetricValueStore.add_metric_value("some label", 111, 222, context: %{some: :thing})
    [metric_value] = MetricValueStore.pop_metric_values()
    assert metric_value.context == [{"some", "thing"}]

    MetricValueStore.add_metric_value("some label", 111, 222, context: %{"number" => 12.34})
    [metric_value] = MetricValueStore.pop_metric_values()
    assert metric_value.context == [{"number", "12.34"}]

    MetricValueStore.add_metric_value("some label", 111, 222, context: %{a: 1, b: 2})
    [metric_value] = MetricValueStore.pop_metric_values()
    assert metric_value.context |> Enum.sort() == [{"a", "1"}, {"b", "2"}]
  end

  test "pop_metric_values" do
    MetricValueStore.add_metric_value("some label", 111, 222, %{})
    assert [_] = MetricValueStore.pop_metric_values()
    assert [] = MetricValueStore.pop_metric_values()
  end

  test "limits number of stored metric values" do
    Application.put_env(:pryin, :max_tracked_metric_values_for_interval, 3)
    MetricValueStore.add_metric_value("some label", 222, 111, %{})
    MetricValueStore.add_metric_value("some label", 333, 111, %{})
    MetricValueStore.add_metric_value("some other label", 444, 111, %{})
    MetricValueStore.add_metric_value("some label", 555, 111, %{})
    popped_metric_values = MetricValueStore.pop_metric_values()
    assert length(popped_metric_values) == 3
    refute 555 in Enum.map(popped_metric_values, & &1.value)

    assert MetricValueStore.pop_metric_values() == []
  end
end
