defmodule PryIn.Api.Live do
  require Logger

  @moduledoc """
  Live Api module for PryIn.
  """
  @behaviour PryIn.Api
  @env Application.get_env(:pryin, :env)


  defmodule HTTP do
    use HTTPoison.Base
    @moduledoc false

    @prod_base_url "https://client.pryin.io/api/client"

    defp process_request_headers(headers) do
      [{"Content-Type", "application/json"} | headers]
    end

    defp process_url(path) do
      Path.join([base_url, path])
    end

    defp base_url do
      Application.get_env(:pryin, :base_url, @prod_base_url)
    end
  end

  @doc """
  Send a list of interactions to the PryIn Api.

  If `config :pryin, enabled: false`, interactions won't be sent.
  """
  def send_interactions(interactions) do
    body = %{
      api_key: api_key,
      interactions: interactions,
      env: @env,
    }
    |> Poison.encode!

    if Application.get_env(:pryin, :enabled) do
      case HTTP.post("interactions", body) do
        {:ok, %{status_code: 201}} -> :ok
        response -> Logger.warn "Could not send interactions to PryIn: #{inspect response}"
      end
    end
  end

  defp api_key do
    Application.get_env(:pryin, :api_key)
  end
end
