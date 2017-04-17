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
end
