defmodule Skope.TestPlugApp do
  import Plug.Conn
  use Plug.Router
  plug Skope.Plug

  plug :match
  plug :dispatch

  get "/test" do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "Hello world")
  end
end
