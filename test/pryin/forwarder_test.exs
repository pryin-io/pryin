defmodule PryIn.ForwarderTest do
  use PryIn.Case
  alias PryIn.{Interaction, InteractionStore, Data}

  test "does not forward an empty interactions list" do
    send(PryIn.Forwarder, :forward_interactions)
    refute_receive {:data_sent, _}
  end

  test "sends finished interactions" do
    interaction_1 = Interaction.new(start_time: 1000, duration: 1, interaction_id: "i1", type: :request)
    pid_1 = spawn fn -> :timer.sleep(5000) end
    interaction_2 = Interaction.new(start_time: 1000, duration: 2, interaction_id: "i2", type: :request)
    pid_2 = spawn fn -> :timer.sleep(5000) end
    interaction_3 = Interaction.new(start_time: 1000, duration: 3, interaction_id: "i3", type: :request)
    pid_3 = spawn fn -> :timer.sleep(5000) end

    InteractionStore.start_interaction(pid_1, interaction_1)
    InteractionStore.finish_interaction(pid_1)
    InteractionStore.start_interaction(pid_2, interaction_2)
    InteractionStore.finish_interaction(pid_2)
    InteractionStore.start_interaction(pid_3, interaction_3)

    send(PryIn.Forwarder, :forward_interactions)
    assert_receive {:data_sent, encoded_data}
    data = Data.decode(encoded_data)
    assert data.env == Application.get_env(:pryin, :env)

    interactions = data.interactions
    assert length(interactions) == 2

    sent_interaction_1 = Enum.find(interactions, & &1.interaction_id == "i1")
    assert sent_interaction_1.start_time == 1
    assert sent_interaction_1.duration == 1

    sent_interaction_2 = Enum.find(interactions, & &1.interaction_id == "i2")
    assert sent_interaction_2.start_time == 1
    assert sent_interaction_2.duration == 2
  end
end
