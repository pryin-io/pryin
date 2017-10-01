defmodule PryIn.TimeHelper do
  @moduledoc false

  def utc_unix_datetime do
    DateTime.utc_now |> DateTime.to_unix(:microseconds)
  end
end
