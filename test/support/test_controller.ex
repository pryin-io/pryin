defmodule Skope.TestController do
  use Phoenix.Controller
  require Skope.TestEndpoint

  plug :put_layout, false

  def test_action(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "Hello world")
  end
end
