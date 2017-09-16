defmodule PryIn.Factory do
  use ExMachina

  def request_factory do
    %PryIn.Interaction{
      type: :request,
      interaction_id: sequence(:request_id, &"request_id-#{&1}"),
      action: "some_action",
      controller: "SomeApp.SomeController",
      duration: 12_345,
      start_time: 1_491_848_831_944_116,
    }
  end

  def channel_receive_factory do
    %PryIn.Interaction{
      type: :channel_receive,
      interaction_id: sequence(:request_id, &"request_id-#{&1}"),
      channel: "MyApp.SomeChannel",
      topic: "some:topic",
      event: "some:event",
      duration: 12_345,
      start_time: 1_491_848_831_944_116,
    }
  end

  def channel_join_factory do
    %PryIn.Interaction{
      type: :channel_join,
      interaction_id: sequence(:request_id, &"request_id-#{&1}"),
      channel: "MyApp.SomeChannel",
      topic: "some:topic",
      duration: 12_345,
      start_time: 1_491_848_831_944_116,
    }
  end

  def custom_trace_factory do
    %PryIn.Interaction{
      type: :custom_trace,
      interaction_id: sequence(:request_id, &"custom_trace_id-#{&1}"),
      custom_group: "some group",
      custom_key: "some_key",
      duration: 12_345,
      start_time: 1_491_848_831_944_116,
    }
  end

  def metric_value_factory do
    %PryIn.MetricValue{
      label: "some label",
      value: 12.345,
      start_time: 1_491_848_831_944_116,
    }
  end
end
