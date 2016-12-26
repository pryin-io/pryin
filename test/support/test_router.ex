defmodule Skope.TestRouter do
  use Phoenix.Router

  pipeline :browser do
    plug Skope.Plug
  end

  scope "/" do
    pipe_through :browser
    get "/test", Skope.TestController, :test_action
  end
end
