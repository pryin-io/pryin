defmodule PryIn.BaseForwarder do
  alias PryIn.Data

  @api Application.get_env(:pryin, :api, PryIn.Api.Live)
  @env Application.get_env(:pryin, :env)
  unless @env in [:dev, :staging, :prod], do: raise """
  PryIn `env` configuration needs to be one of :dev, :staging, :prod.
  Got #{inspect @env}.
  """

  def wrap_data(data) do
    [
      env: @env,
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
    node() |> to_string()
  end
end
