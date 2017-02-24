defmodule PryIn.Api do
  @moduledoc """
  Behaviour for the API module.
  Implemented by `PryIn.Api.Live` for real API calls
  and by `PryIn.Api.Test` for testing.
  """

  @callback send_interactions(PryIn.Data.t) :: :ok
  @callback send_system_metrics(PryIn.Data.t) :: :ok
end
