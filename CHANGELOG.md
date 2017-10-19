# Changelog

## vNext

- rate sampling for tracked metrics and custom traces
- PryIn.GenServer for GenServer instrumentation

## v1.4.0

- add `PryIn.track_metric` to track metrics outside of traces

## v1.3.0

- allow adding context (user id, ...) to traces with `PryIn.put_context/2`
- implement custom instrumentation without phoenix for nicer usage in umbrella apps

## v1.2.1

- handle Ecto log entries with functions as query
- prevent errors when traces finish during instrumentation

## v1.2.0

- remove httpoison dependency, use hackney directly
- add `PryIn.drop_trace()` to prevent traces from being forwarded

## v1.1.2

- fix for when connection_pid in an Ecto.LogEntry is nil

## v1.1.1

- fix preload queries not appearing in traces for newer ecto versions

## v1.1.0

- __Multi process traces__: User `PryIn.join_trace(parent_pid, child_pid)` to add a child process to a running trace.
- [Bugfix] Do not forward controller traces with empty action
- [Bugfix] Do not forward controller or custom traces when required values are empty strings. Until now, only `nil` was checked for.
