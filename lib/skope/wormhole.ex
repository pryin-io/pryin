defmodule Skope.Wormhole do
  @moduledoc """
  Run a function capturing any errors.
  """

  def capture(callback) do
    Task.Supervisor.start_link
    |> execute_callback(callback)
  end

  defp execute_callback({:ok, supervisor}, callback) do
    Task.Supervisor.async_nolink(supervisor, callback)
    |> Task.yield
    |> stop_supervisor(supervisor)
    |> response_format
  end
  defp execute_callback(start_link_response, _callback) do
    {:error, {:failed_to_start_supervisor, start_link_response}}
  end

  defp stop_supervisor(response, supervisor) do
    Process.unlink(supervisor)
    Process.exit(supervisor, :kill)

    response
  end

  defp response_format({:ok,   state}), do: {:ok,    state}
  defp response_format({:exit, reason}), do: {:error, reason}
  defp response_format(nil), do: {:error, :timeout}
end
