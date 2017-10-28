defmodule PryIn.BaseForwarder do
  alias PryIn.Data
  require Logger

  @moduledoc false

  @api Application.get_env(:pryin, :api, PryIn.Api.Live)
  @allowed_envs [:dev, :staging, :prod]

  def wrap_data(data) do
    [
      env: env(),
      pryin_version: pryin_version(),
      app_version: app_version(),
      node_name: node_name(),
    ]
    |> Keyword.merge(data)
    |> Data.new
    |> Data.encode
  end

  def api do
    @api
  end

  defp pryin_version do
    Application.spec(:pryin, :vsn) |> to_string
  end

  defp app_version do
    if app_name = Application.get_env(:pryin, :otp_app) do
      Application.spec(app_name, :vsn) |> to_string()
    end
  end

  defp node_name do
    Application.get_env(:pryin, :node_name) || to_string(node())
  end

  defp env do
    case Application.get_env(:pryin, :env) do
      val when val in @allowed_envs -> val
      val when is_binary(val) -> env_to_atom(val)
      val -> wrong_env(val)
    end
  end

  defp env_to_atom(binary_env) do
    case String.to_atom(binary_env) do
      val when val in @allowed_envs -> val
      val -> wrong_env(val)
    end
  end

  defp wrong_env(val) do
    Logger.error "[PryIn] `env` configuration needs to be one of #{inspect @allowed_envs}. Got #{inspect val}"
    :dev
  end
end
