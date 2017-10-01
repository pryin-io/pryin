defmodule PryIn.Api.Live do
  require Logger

  @moduledoc false
  @behaviour PryIn.Api
  @prod_base_url "https://client.pryin.io/api/client/v2"
  @headers  [{"Content-Type", "application/octet-stream"}]


  # Send interaction data to the PryIn Api.
  # If `config :pryin, enabled: false`, data won't be sent.
  def send_data(data) do
    if Application.get_env(:pryin, :enabled) do
      case :hackney.post(make_url("data?api_key=#{api_key()}"), @headers, data, [pool: :pryin_pool, with_body: true]) do
        {:ok, 201, _, _} -> :ok
        {:ok, status, _, body} ->
          Logger.warn "[PryIn] Could not send interactions to PryIn: [#{inspect status}] - #{inspect body}"
        {:error, _} = response -> Logger.warn "[PryIn] Could not send interactions to PryIn: #{inspect response}"
      end
    end
  end

  # Send system metric data to the PryIn Api.
  # If `config :pryin, enabled: false`, data won't be sent
  def send_system_metrics(data) do
    if Application.get_env(:pryin, :enabled) do
      case :hackney.post(make_url("system_metrics?api_key=#{api_key()}"), @headers, data, [pool: :pryin_pool, with_body: true]) do
        {:ok, 201, _, _} -> :ok
        {:ok, status, _, body} ->
          Logger.warn "[PryIn] Could not send system metrics to PryIn: [#{inspect status}] - #{inspect body}"
        {:error, _} = response -> Logger.warn "[PryIn] Could not send system metrics to PryIn: #{inspect response}"
      end
    end
  end

  defp api_key do
    Application.get_env(:pryin, :api_key)
  end

  defp make_url(path) do
    Path.join([base_url(), path])
  end

  defp base_url do
    Application.get_env(:pryin, :base_url, @prod_base_url)
  end

end
