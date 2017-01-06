defmodule PryIn.Api do
  @callback send_interactions([PryIn.Interaction.t]) :: :ok
end
