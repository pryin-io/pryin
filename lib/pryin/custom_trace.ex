defmodule PryIn.CustomTrace do
  alias PryIn.{TimeHelper, Interaction, InteractionStore, Wormhole, InteractionHelper}

  @moduledoc """
  Functions for managing custom traces.

  This can be used to trace for example background jobs.

  Start a trace with `PryIn.CustomTrace.start(group: "workers", key: "daily_email_worker")`
  and when the worker is done, call the finish function in the same process with `PryIn.CustomTrace.finish()`.

  `group` and `key` are values you can choose freely. They will appear in the web interface and allow you to aggregate
  and compare traces over time. A `group` can be added to the sidebar navigation for easy access.
  Good values for `group` can be for example `"background_jobs"` or `absinthe_requests`
  if you're using that for GraphQl. Examples for `key` could then be `"daily_email_job"` or `"all_todos_query"`.

  Any metric that is associated with the process `PryIn.CustomTrace.start` was called in will
  be recorded.

  You can set a group and key later (before calling `finish()`) with `PryIn.CustomTrace.set_group("some_group")`
  and `PryIn.CustomTrace.set_key("some_group")`.

  *IMPORTANT:* If group and key are not set, the trace will not be forwarded to PryIn and so won't appear
  in the web interface.
  """


  @doc """
  Starts a custom trace.
  Can alreay set group and key for the trace:

  `PryIn.CustomTrace.start(group: "some_group", key: "some_key")`
  """
  def start(opts \\ []) do
    req_start_time = TimeHelper.utc_unix_datetime()
    interaction = Interaction.new(start_time: req_start_time,
      type: :custom_trace,
      custom_group: opts[:group],
      custom_key: opts[:key])
    InteractionStore.start_interaction(self(), interaction)
  end

  @doc """
  Sets the group for the custom trace started by calling
  `PryIn.CustomTrace.start()` within the same process.
  """
  def set_group(group) do
    pid = self()
    Wormhole.capture(fn ->
      if InteractionStore.has_pid?(pid) do
        InteractionStore.set_interaction_data(pid, %{custom_group: group})
      end
    end)
  end

  @doc """
  Sets the key for the custom trace started by calling
  `PryIn.CustomTrace.start()` within the same process.
  """
  def set_key(key) do
    pid = self()
    Wormhole.capture(fn ->
      if InteractionStore.has_pid?(pid) do
        InteractionStore.set_interaction_data(pid, %{custom_key: key})
      end
    end)
  end

  @doc """
  Finishes the custom trace started by calling
  `PryIn.CustomTrace.start()` within the same process.

  *Important:* You need to set :group and :key at some point before
  calling `finish()`. Otherwise the trace will be ignored.
  """
  def finish do
    pid = self()
    Wormhole.capture(fn ->
      if InteractionStore.has_pid?(pid) do
        duration = TimeHelper.utc_unix_datetime() - InteractionStore.get_field(pid, :start_time)
        interaction_id = maybe_generate_interaction_id(pid)
        InteractionStore.set_interaction_data(pid, %{duration: duration, interaction_id: interaction_id})
        InteractionStore.finish_interaction(pid)
      end
    end)
  end


  defp maybe_generate_interaction_id(pid) do
    case InteractionStore.get_field(pid, :interaction_id) do
      "" -> InteractionHelper.generate_interaction_id()
      nil -> InteractionHelper.generate_interaction_id()
      interaction_id -> interaction_id
    end
  end

end
