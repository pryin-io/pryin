defmodule PryIn.Api do
  @moduledoc """
  Behaviour for the API module.
  Implemented by `PryIn.Api.Live` for real API calls
  and by `PryIn.Api.Test` for testing.
  """

  @callback send_interactions([PryIn.Interaction.t]) :: :ok
end
