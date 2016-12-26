defmodule Skope.TestRouter do
  use Phoenix.Router

  pipeline :browser do
    plug Skope.Plug
  end

  scope "/" do
    pipe_through :browser
    get "/test", Skope.TestController, :test_action
    get "/render_test", Skope.TestController, :render_action
    get "/custom_instrumentation", Skope.TestController, :custom_instrumentation_action
  end
end
