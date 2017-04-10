defmodule PryIn.InteractionHelperTest do
  use PryIn.Case
  alias PryIn.InteractionHelper

  test "module_name" do
    assert InteractionHelper.module_name(nil) == nil
    assert InteractionHelper.module_name(MyApp.MyModule) == "MyApp.MyModule"
    assert InteractionHelper.module_name(:my_app) == "my_app"
    assert InteractionHelper.module_name("MyApp.MyModule") == "MyApp.MyModule"
    assert InteractionHelper.module_name(123) == nil
  end
end
