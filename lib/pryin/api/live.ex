defmodule PryIn.Api.Live do
  require Logger

  @moduledoc """
  Live Api module for PryIn.
  """
  @behaviour PryIn.Api


  defmodule HTTP do
    use HTTPoison.Base
    @moduledoc false

    @prod_base_url "https://client.pryin.io/api/client"

    defp process_url(path) do
      Path.join([base_url, path])
    end

    defp process_request_headers(headers) do
      [{"Content-Type", "application/octet-stream"} | headers]
    end

    defp base_url do
      Application.get_env(:pryin, :base_url, @prod_base_url)
    end
  end

  @doc """
  Send a list of interactions to the PryIn Api.

  If `config :pryin, enabled: false`, interactions won't be sent.
  """
  def send_data(data) do
    if Application.get_env(:pryin, :enabled) do
      case HTTP.post("data/#{api_key()}", data) do
        {:ok, %{status_code: 201}} -> :ok
        response -> Logger.warn "Could not send interactions to PryIn: #{inspect response}"
      end
    end
  end

  defp api_key do
    Application.get_env(:pryin, :api_key)
  end
end
