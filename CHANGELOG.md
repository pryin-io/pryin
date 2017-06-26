# Changelog

## 1.1.1

- fix preload queries not appearing in traces for newer ecto versions

## 1.1.0

- __Multi process traces__: User `PryIn.join_trace(parent_pid, child_pid)` to add a child process to a running trace.
- [Bugfix] Do not forward controller traces with empty action
- [Bugfix] Do not forward controller or custom traces when required values are empty strings. Until now, only `nil` was checked for.
