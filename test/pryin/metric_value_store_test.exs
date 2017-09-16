defmodule PryIn.MetricValueStoreTest do
  use PryIn.Case
  alias PryIn.MetricValueStore

  test "add_metric_value" do
    MetricValueStore.add_metric_value("some label", 111, 222, %{})
    [metric_value] = MetricValueStore.pop_metric_values
    assert metric_value.label      == "some label"
    assert metric_value.value      == 111
    assert metric_value.start_time == 222
    assert metric_value.context    == []

    MetricValueStore.add_metric_value("some label", 111, 222, context: %{some: :thing})
    [metric_value] = MetricValueStore.pop_metric_values
    assert metric_value.context == [{"some", "thing"}]

    MetricValueStore.add_metric_value("some label", 111, 222, context: %{"number" => 12.34})
    [metric_value] = MetricValueStore.pop_metric_values
    assert metric_value.context == [{"number", "12.34"}]

    MetricValueStore.add_metric_value("some label", 111, 222, context: %{a: 1, b: 2})
    [metric_value] = MetricValueStore.pop_metric_values
    assert metric_value.context |> Enum.sort == [{"a", "1"}, {"b", "2"}]
  end

  test "pop_metric_values" do
    MetricValueStore.add_metric_value("some label", 111, 222, %{})
    assert [_] = MetricValueStore.pop_metric_values
    assert [] = MetricValueStore.pop_metric_values
  end
end
