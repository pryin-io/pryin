defmodule PryIn.InteractionHelper do
  @moduledoc """
  Interaction related helper functions.
  """

  @doc """
  Generate a random id for an interaction.
  """
  def generate_interaction_id do
    :crypto.strong_rand_bytes(20) |> Base.hex_encode32(case: :lower)
  end


  @doc """
  Transform a module name into a string.
  """
  def module_name(nil), do: nil
  def module_name(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> String.replace(~r/^Elixir\./, "")
  end
  def module_name(module) when is_binary(module), do: module
  def module_name(_), do: nil
end
