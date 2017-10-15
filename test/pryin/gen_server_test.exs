defmodule PryIn.GenServerTest do
  use PryIn.Case

  defmodule TestGenServer do
    use GenServer
    use PryIn.GenServer, values: %{
      "TestGenServer queue length" => {&__MODULE__.queue_length/1, 100}
    }

    def start_link(default) do
      GenServer.start_link(__MODULE__, default)
    end

    def init(_) do
      {:ok, 0}
    end

    def queue_length(state) do
      {:ok, state, state + 1}
    end
  end

  test "collects and forwards metrics as configured" do
    {:ok, _pid} = TestGenServer.start_link([])
    :timer.sleep(150)
    [metric_value] = PryIn.MetricValueStore.pop_metric_values
    assert metric_value.label == "TestGenServer queue length"
    assert metric_value.value == 0

    :timer.sleep(150)
    [metric_value] = PryIn.MetricValueStore.pop_metric_values
    assert metric_value.label == "TestGenServer queue length"
    assert metric_value.value == 1
  end
end
