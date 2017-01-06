defmodule PryIn.TestEndpoint do
  use Phoenix.Endpoint, otp_app: :phoenix
  plug PryIn.TestRouter
end
