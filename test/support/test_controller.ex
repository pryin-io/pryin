defmodule PryIn.TestController do
  use Phoenix.Controller
  require PryIn.TestEndpoint

  plug :put_layout, false

  def test_action(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "Hello world")
  end

  def render_action(conn, _params) do
    render(conn, "test_template.html")
  end

  def custom_instrumentation_action(conn, _params) do
    PryIn.TestEndpoint.instrument :pryin, %{key: "expensive_api_call"}, fn ->
      :timer.sleep(1)
    end

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "Hello world")
  end
end
