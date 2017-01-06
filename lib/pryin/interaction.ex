defmodule PryIn.Interaction do
  @moduledoc """
  Base struct for interaction based measurements.
  All other measurements (DB queries, custom measurements) are children of an interaction.
  """

  defstruct [:type, :start_time, :duration, :action, :controller, :interaction_id, extra_data: []]

end
