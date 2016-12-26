defmodule Skope.Api.Live do
  use HTTPoison.Base
  require Logger

  @moduledoc """
  Api module for Skope
  """
  @behaviour Skope.Api
  @prod_base_url "https://client.skope.io/api/client"
  @env Application.fetch_env!(:skope, :env)

  def send_interactions(interactions) do
    body = %{
      api_key: api_key,
      interactions: interactions,
      env: @env,
    }
    |> Poison.encode!

    if Application.get_env(:skope, :enabled) do
      case post("interactions", body) do
        {:ok, %{status_code: 201}} -> :ok
        response -> Logger.warn "Could not send interactions to Skope: #{inspect response}"
      end
    end
  end


  defp process_request_headers(headers) do
    [{"Content-Type", "application/json"} | headers]
  end

  defp process_url(path) do
    Path.join([base_url, path])
  end

  defp base_url do
    Application.get_env(:skope, :base_url, @prod_base_url)
  end

  defp api_key do
    Application.get_env(:skope, :api_key)
  end
end
