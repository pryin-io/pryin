defmodule PryIn do
  for file <- Path.wildcard("lib/proto/*.proto") do
    @external_resource file
  end
  use Protobuf, from: Path.wildcard("lib/proto/*.proto")
  use Application
  @moduledoc """
  PryIn is a performance metrics platform for your Phoenix application.

  This is the main entry point for the client library.
  It starts an InteractionStore (which holds a list of interaction (e.g. web request) metrics)
  and a InteractionForwarder (which polls the InteractionStore for metrics and forwards them to the api).
  """

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      :hackney_pool.child_spec(:pryin_pool, [timeout: 60_000, max_connections: 5]),
      worker(PryIn.InteractionStore, []),
      worker(PryIn.InteractionForwarder, []),
      worker(PryIn.SystemMetricsCollector, []),
    ]

    opts = [strategy: :rest_for_one, name: PryIn.Supervisor]
    Supervisor.start_link(children, opts)
  end


  @doc """
  Join a process into a running trace.

  Use this to add metrics from a child process to a parent process.
  Example:

  ```
  def index(conn, params) do
    ...
    parent_pid = self()
    task = Task.async(fn ->
      PryIn.join_trace(parent_pid, self())
      Repo.all(User)
      ...
    end)
    Task.await(task)
    ...
  end
  ```

  Without calling `join_trace` here, the `Repo.all` call would not be added to the
  trace of the `index` action, as it happens in a different process.
  """
  def join_trace(parent_pid, child_pid) do
    PryIn.InteractionStore.add_child(parent_pid, child_pid)
  end


  @doc """
  Drops a running trace.

  Use this if you don't want a trace being forwarded to PryIn.
  Must be called after the trace was started.

  Example:

  ```
  def index(conn, params) do
    PryIn.drop_trace()
    ...
  end
  ```
  """
  def drop_trace(pid \\ self()) do
    PryIn.InteractionStore.drop_interaction(pid)
  end



  @doc """
  Add context to a running trace.

  Both arguments need to implement the `String.Chars` protocol,
  so `to_string/1` can be called with them.

  Example:

  ```
  def index(conn, params) do
    PryIn.put_context(:user_id, conn.assigns.user.id)
  ...
  end
  ```
  """
  def put_context(key, value, pid \\ self()) do
    if PryIn.InteractionStore.has_pid?(pid) do
      PryIn.InteractionStore.put_context(pid, key, value)
    end
  end
end
