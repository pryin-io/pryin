defmodule Skope.TestEndpoint do
  use Phoenix.Endpoint, otp_app: :phoenix
  plug Skope.TestRouter
end
