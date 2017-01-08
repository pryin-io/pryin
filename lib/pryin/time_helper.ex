defmodule PryIn.TimeHelper do
  @moduledoc """
  Common functions for handling time.
  """

  @doc """
  Returns the current time as a microsecond timestamp.
  """
  def utc_unix_datetime do
    DateTime.utc_now |> DateTime.to_unix(:microseconds)
  end
end
