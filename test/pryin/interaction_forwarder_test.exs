defmodule PryIn.InteractionForwarderTest do
  use PryIn.Case
  alias PryIn.{InteractionStore, Data}

  test "does not forward an empty interactions list" do
    {:ok, forwarder} = PryIn.InteractionForwarder.start_link()
    send(forwarder, :forward_interactions)

    refute_receive {:interactions_sent, _}
  end

  property "sends finished interactions" do
    check all interaction_id_1 <- PropertyHelpers.non_empty_string(),
      interaction_id_2 <- PropertyHelpers.non_empty_string(),
      interaction_id_3 <- PropertyHelpers.non_empty_string() do
      interaction_1 = Factory.build(:request, start_time: 1000, duration: 1, interaction_id: interaction_id_1)
      pid_1 = spawn fn -> :timer.sleep(5000) end
      interaction_2 = Factory.build(:request, start_time: 1000, duration: 2, interaction_id: interaction_id_2)
      pid_2 = spawn fn -> :timer.sleep(5000) end
      interaction_3 = Factory.build(:request, start_time: 1000, duration: 3, interaction_id: interaction_id_3)
      pid_3 = spawn fn -> :timer.sleep(5000) end

      InteractionStore.start_interaction(pid_1, interaction_1)
      InteractionStore.finish_interaction(pid_1)
      InteractionStore.start_interaction(pid_2, interaction_2)
      InteractionStore.finish_interaction(pid_2)
      InteractionStore.start_interaction(pid_3, interaction_3)

      {:ok, forwarder} = PryIn.InteractionForwarder.start_link()
      send(forwarder, :forward_interactions)
      assert_receive {:interactions_sent, encoded_data}
      data = Data.decode(encoded_data)
      interactions = data.interactions
      assert length(interactions) == 2

      sent_interaction_1 = Enum.find(interactions, & &1.duration == 1)
      assert sent_interaction_1.start_time == 1
      assert sent_interaction_1.interaction_id == interaction_id_1

      sent_interaction_2 = Enum.find(interactions, & &1.duration == 2)
      assert sent_interaction_2.start_time == 1
      assert sent_interaction_2.interaction_id == interaction_id_2
    end
  end

  test "includes metadata" do
    interaction_1 = Factory.build(:request, start_time: 1000, duration: 1, interaction_id: "i1")
    pid_1 = spawn fn -> :timer.sleep(5000) end

    InteractionStore.start_interaction(pid_1, interaction_1)
    InteractionStore.finish_interaction(pid_1)

    {:ok, forwarder} = PryIn.InteractionForwarder.start_link()
    send(forwarder, :forward_interactions)
    assert_receive {:interactions_sent, encoded_data}
    data = Data.decode(encoded_data)
    assert data.env == :dev
    assert data.pryin_version == "1.3.0"
    assert data.app_version == "1.2.7" # otp_app ist set to :exprotobuf
  end

  property "includes the env setting" do
    check all env <- member_of([:dev, :staging, :prod, "dev", "staging", "prod"]) do
      Application.put_env(:pryin, :env, env)
      interaction_1 = Factory.build(:request)
      InteractionStore.start_interaction(self(), interaction_1)
      InteractionStore.finish_interaction(self())

      {:ok, forwarder} = PryIn.InteractionForwarder.start_link()
      send(forwarder, :forward_interactions)
      assert_receive {:interactions_sent, encoded_data}
      data = Data.decode(encoded_data)
      assert data.env == env |> to_string |> String.to_atom()
      Application.put_env(:pryin, :env, :dev)
    end
  end

  test "defaults to dev for different values" do
    Application.put_env(:pryin, :env, "different_env")
    interaction_1 = Factory.build(:request)
    InteractionStore.start_interaction(self(), interaction_1)
    InteractionStore.finish_interaction(self())

    captured_log = ExUnit.CaptureLog.capture_log [level: :error], fn ->
      {:ok, forwarder} = PryIn.InteractionForwarder.start_link()
      send(forwarder, :forward_interactions)
      assert_receive {:interactions_sent, encoded_data}
      data = Data.decode(encoded_data)
      assert data.env == :dev
    end
    assert captured_log =~ "[PryIn] `env` configuration needs to be one of [:dev, :staging, :prod]. Got :different_env"
    Application.put_env(:pryin, :env, :dev)
  end
end
