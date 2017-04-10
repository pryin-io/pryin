defmodule PryIn.TestEndpoint do
  use Phoenix.Endpoint, otp_app: :phoenix
  socket "/socket", PryIn.TestSocket

  plug PryIn.TestRouter
end
