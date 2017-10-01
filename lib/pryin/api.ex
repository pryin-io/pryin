defmodule PryIn.Api do
  @moduledoc false

  @callback send_data(PryIn.Data.t) :: :ok
  @callback send_system_metrics(PryIn.Data.t) :: :ok
end
