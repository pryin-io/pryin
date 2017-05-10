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
      Path.join([base_url(), path])
    end

    defp process_request_headers(headers) do
      [{"Content-Type", "application/octet-stream"} | headers]
    end

    defp base_url do
      Application.get_env(:pryin, :base_url, @prod_base_url)
    end
  end

  @doc """
  Send interaction data to the PryIn Api.

  If `config :pryin, enabled: false`, data won't be sent.
  """
  def send_interactions(data) do
    if Application.get_env(:pryin, :enabled) do
      case HTTP.post("interactions/#{api_key()}", data, [], [hackney: [pool: :pryin_pool]]) do
        {:ok, %{status_code: 201}} -> :ok
        {:ok, %{status: status, body: body}} -> Logger.warn "[PryIn] Could not send interactions to PryIn: [#{inspect status}] - #{inspect body}"
        response -> Logger.warn "[PryIn] Could not send interactions to PryIn: #{inspect response}"
      end
    end
  end

  @doc """
  Send system metric data to the PryIn Api.

  If `config :pryin, enabled: false`, data won't be sent
  """
  def send_system_metrics(data) do
    if Application.get_env(:pryin, :enabled) do
      case HTTP.post("system_metrics/#{api_key()}", data, [], [hackney: [pool: :pryin_pool]]) do
        {:ok, %{status_code: 201}} -> :ok
        {:ok, %{status: status, body: body}} -> Logger.warn "[PryIn] Could not send system metrics to PryIn: [#{inspect status}] - #{inspect body}"
        response -> Logger.warn "[PryIn] Could not send system metrics to PryIn: #{inspect response}"
      end
    end
  end

  defp api_key do
    Application.get_env(:pryin, :api_key)
  end
end
