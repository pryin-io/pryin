defmodule Skope.Api do
  @callback send_interactions([Skope.Interaction.t]) :: :ok
end
