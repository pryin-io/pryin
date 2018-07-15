defmodule PryIn.DataForwarderTest do
  use PryIn.Case
  alias PryIn.{InteractionStore, Data, MetricValueStore}

  test "does not forward an empty interactions list" do
    send(PryIn.DataForwarder, :forward_data)
    refute_receive {:data_sent, _}
  end

  test "sends finished interactions" do
    interaction_1 = Factory.build(:request, start_time: 1000, duration: 1, interaction_id: "i1")
    pid_1 = spawn(fn -> :timer.sleep(5000) end)
    interaction_2 = Factory.build(:request, start_time: 1000, duration: 2, interaction_id: "i2")
    pid_2 = spawn(fn -> :timer.sleep(5000) end)
    interaction_3 = Factory.build(:request, start_time: 1000, duration: 3, interaction_id: "i3")
    pid_3 = spawn(fn -> :timer.sleep(5000) end)

    InteractionStore.start_interaction(pid_1, interaction_1)
    InteractionStore.finish_interaction(pid_1)
    InteractionStore.start_interaction(pid_2, interaction_2)
    InteractionStore.finish_interaction(pid_2)
    InteractionStore.start_interaction(pid_3, interaction_3)

    send(PryIn.DataForwarder, :forward_data)
    assert_receive {:data_sent, encoded_data}
    data = Data.decode(encoded_data)
    interactions = data.interactions
    assert length(interactions) == 2

    sent_interaction_1 = Enum.find(interactions, &(&1.interaction_id == "i1"))
    assert sent_interaction_1.start_time == 1
    assert sent_interaction_1.duration == 1

    sent_interaction_2 = Enum.find(interactions, &(&1.interaction_id == "i2"))
    assert sent_interaction_2.start_time == 1
    assert sent_interaction_2.duration == 2
  end

  test "sends metric values" do
    MetricValueStore.add_metric_value("l1", 1, 1000, %{})
    MetricValueStore.add_metric_value("l2", 2, 2000, %{context: %{hello: :there}})

    send(PryIn.DataForwarder, :forward_data)
    assert_receive {:data_sent, encoded_data}
    data = Data.decode(encoded_data)
    metric_values = data.metric_values
    assert length(metric_values) == 2

    sent_metric_value_1 = Enum.find(metric_values, &(&1.label == "l1"))
    assert sent_metric_value_1.start_time == 1000
    assert sent_metric_value_1.value == 1

    sent_metric_value_2 = Enum.find(metric_values, &(&1.label == "l2"))
    assert sent_metric_value_2.start_time == 2000
    assert sent_metric_value_2.value == 2
    assert sent_metric_value_2.context == [{"hello", "there"}]
  end

  test "includes metadata" do
    interaction_1 = Factory.build(:request, start_time: 1000, duration: 1, interaction_id: "i1")
    pid_1 = spawn(fn -> :timer.sleep(5000) end)

    InteractionStore.start_interaction(pid_1, interaction_1)
    InteractionStore.finish_interaction(pid_1)

    send(PryIn.DataForwarder, :forward_data)
    assert_receive {:data_sent, encoded_data}
    data = Data.decode(encoded_data)
    assert data.env == :dev
    assert data.pryin_version == "1.5.2"
    # otp_app ist set to :exprotobuf
    assert data.app_version == "1.2.9"
  end

  for env <- ~w(dev staging prod)a do
    test "allows atom #{env} as env setting" do
      Application.put_env(:pryin, :env, unquote(env))
      interaction_1 = Factory.build(:request)
      InteractionStore.start_interaction(self(), interaction_1)
      InteractionStore.finish_interaction(self())

      send(PryIn.DataForwarder, :forward_data)
      assert_receive {:data_sent, encoded_data}
      data = Data.decode(encoded_data)
      assert data.env == unquote(env)
      Application.put_env(:pryin, :env, :dev)
    end
  end

  for env <- ~w(dev staging prod) do
    test "allows string #{env} as env setting" do
      Application.put_env(:pryin, :env, unquote(env))
      interaction_1 = Factory.build(:request)
      InteractionStore.start_interaction(self(), interaction_1)
      InteractionStore.finish_interaction(self())

      send(PryIn.DataForwarder, :forward_data)
      assert_receive {:data_sent, encoded_data}
      data = Data.decode(encoded_data)
      assert data.env == String.to_atom(unquote(env))
      Application.put_env(:pryin, :env, :dev)
    end
  end

  test "defaults to dev for different values" do
    Application.put_env(:pryin, :env, "different_env")
    interaction_1 = Factory.build(:request)
    InteractionStore.start_interaction(self(), interaction_1)
    InteractionStore.finish_interaction(self())

    captured_log =
      ExUnit.CaptureLog.capture_log([level: :error], fn ->
        send(PryIn.DataForwarder, :forward_data)
        assert_receive {:data_sent, encoded_data}
        data = Data.decode(encoded_data)
        assert data.env == :dev
      end)

    assert captured_log =~
             "[PryIn] `env` configuration needs to be one of [:dev, :staging, :prod]. Got :different_env"

    Application.put_env(:pryin, :env, :dev)
  end
end
