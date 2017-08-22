defmodule PryIn.PropertyHelpers do

  def string() do
    StreamData.alphanumeric_string()
  end

  def to_stringable() do
    StreamData.one_of([
      string(),
      StreamData.int(),
      StreamData.unquoted_atom(),
      StreamData.boolean(),
      StreamData.uniform_float()
    ])
  end

  def positive_int() do
    StreamData.bind(StreamData.int(), fn int ->
      int
      |> abs()
      |> StreamData.constant()
    end)
  end

  def non_empty_string() do
    StreamData.filter(string(), & String.length(&1) > 0, 100)
  end
end
