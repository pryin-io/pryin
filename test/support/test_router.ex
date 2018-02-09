defmodule PryIn.TestRouter do
  use Phoenix.Router

  pipeline :browser do
    plug(PryIn.Plug)
  end

  scope "/" do
    pipe_through(:browser)
    get("/test", PryIn.TestController, :test_action)
    get("/render_test", PryIn.TestController, :render_action)
    get("/custom_instrumentation", PryIn.TestController, :custom_instrumentation_action)
  end
end
