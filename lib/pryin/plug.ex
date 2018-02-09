defmodule PryIn.Plug do
  @behaviour Plug
  import Plug.Conn, only: [register_before_send: 2]
  import PryIn.{TimeHelper, InteractionHelper}
  alias PryIn.{InteractionStore, Interaction}

  @moduledoc """
  Collects metrics about requests.

  Add to your `Plug` pipeline with:

  ```elixir
  plug PryIn.Plug
  ```

  If used in a Phoenix application, it is recommended to add this to your
  `endpoint.ex` right above the `plug MyApp.Router` line.
  """

  @doc false
  def init(opts), do: opts

  @doc false
  def call(conn, _opts) do
    req_start_time = utc_unix_datetime()

    interaction =
      Interaction.new(
        start_time: req_start_time,
        type: :request,
        interaction_id: Logger.metadata()[:request_id] || generate_interaction_id(),
        pid: inspect(self())
      )

    InteractionStore.start_interaction(self(), interaction)

    register_before_send(conn, fn conn ->
      if InteractionStore.has_pid?(self()) do
        duration = utc_unix_datetime() - req_start_time

        interaction_metadata = %{
          action: action_name(conn.private[:phoenix_action]),
          controller: module_name(conn.private[:phoenix_controller]),
          duration: duration
        }

        InteractionStore.set_interaction_data(self(), interaction_metadata)
        InteractionStore.finish_interaction(self())
      end

      conn
    end)
  end

  defp action_name(nil), do: nil
  defp action_name(action), do: to_string(action)
end
