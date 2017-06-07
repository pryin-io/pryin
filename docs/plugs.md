# Tracing Plugs

Plugs that are part of a Phoenix controller pipeline will automatically be included in that controller's traces.

To trace plugs that don't belong to a controller pipeline, you will need to use Custom Traces.

Just call `PryIn.CustomTrace.start(group: "Plugs", key: "name_of_my_plug")` at the beginning
and `PryIn.CustomTrace.finish()` at the end of your plug.

You can also use `Plug.Conn.register_before_send/2` if there are multiple plugs involved.
In the first one start the Custom Trace with `PryIn.CustomTrace.start(...)` and register
a function to be called before the response is finally sent:

```elixir
conn = Plug.Conn.register_before_send(conn, fn conn ->
  PryIn.CustomTrace.finish()
  conn
end)
```
