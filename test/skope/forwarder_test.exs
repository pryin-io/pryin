defmodule Skope.ForwarderTest do
  use Skope.Case
  alias Skope.{Interaction, InteractionStore}

  test "does not forward an empty interactions list" do
    send(Skope.Forwarder, :forward_interactions)
    refute_receive {:interactions_sent, _}
  end

  test "sends finished interactions" do
    interaction_1 = %Interaction{start_time: 1000, duration: 1}
    pid_1 = spawn fn -> :timer.sleep(5000) end
    interaction_2 = %Interaction{start_time: 1000, duration: 2}
    pid_2 = spawn fn -> :timer.sleep(5000) end
    interaction_3 = %Interaction{start_time: 1000, duration: 3}
    pid_3 = spawn fn -> :timer.sleep(5000) end

    InteractionStore.start_interaction(pid_1, interaction_1)
    InteractionStore.finish_interaction(pid_1)
    InteractionStore.start_interaction(pid_2, interaction_2)
    InteractionStore.finish_interaction(pid_2)
    InteractionStore.start_interaction(pid_3, interaction_3)

    send(Skope.Forwarder, :forward_interactions)
    assert_receive {:interactions_sent, interactions}
    assert length(interactions) == 2
    assert %{interaction_1 | start_time: 1} in interactions
    assert %{interaction_2 | start_time: 1} in interactions
  end
end
