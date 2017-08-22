defmodule PryIn.InteractionHelperTest do
  use PryIn.Case
  alias PryIn.InteractionHelper

  property "module_name is a stringified module name" do
    check all module_name <- PropertyHelpers.non_empty_string() do
      assert InteractionHelper.module_name(module_name) == module_name
      assert module_name
      |> String.to_atom()
      |> InteractionHelper.module_name() == module_name
      assert "Elixir"
      |> Module.concat(module_name)
      |> InteractionHelper.module_name() == module_name
    end
  end

  test "module name returns nil when give something that's not a binary or atom" do
    assert InteractionHelper.module_name(nil) == nil
    assert InteractionHelper.module_name(123) == nil
  end
end
