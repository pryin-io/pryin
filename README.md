# PryIn

[![Build Status](https://travis-ci.org/pryin-io/pryin.svg?branch=master)](https://travis-ci.org/pryin-io/pryin)
[![Hex pm](http://img.shields.io/hexpm/v/pryin.svg?style=flat)](https://hex.pm/packages/pryin)

[PryIn](https://pryin.io) is a performance metrics platform for your Phoenix application.

## Installation

  1. Sign up for a [PryIn](https://pryin.io) account and create a new project there.
  2. Add `pryin` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pryin, "~> 1.0"}
  ]
end
```

  3. If you define an applications list in your `mix.exs`, add `:pryin` there, too:
```elixir
def applications do
  [..., :pryin]
end
```

  4. Add general configuration for the pryin app in `config/config.exs`:

```elixir
config :pryin,
  otp_app: :my_app,
  api_key: "your_secret_api_key",
  enabled: false,
  env: :dev

config :my_app, MyApp.Repo,
  loggers: [PryIn.EctoLogger, Ecto.LogEntry]

config :my_app, MyApp.Endpoint,
  instrumenters: [PryIn.Instrumenter]
```


  5. Enable PryIn in the environments you want to collect metrics for.
    If you want to collect data for the production environment, for example,
    add the following to `config/prod.exs`:

```elixir
config :pryin,
  enabled: true,
  env: :prod
```

  Possible values for `env` are `:dev`, `:staging` or `:prod`.

  6. Add the PryIn plug to your application's endpoint (`lib/my_app/endpoint.ex`) just before the router plug:


```elixir
...
plug PryIn.Plug
plug MyApp.Router
```


  7. To collect data about Ecto queries, view renderings or custom instrumentation in your channel joins,
  you need to join the transport's trace first:
```elixir
def join("rooms:lobby", message, socket) do
  PryIn.join_trace(self(), socket.transport_pid)
  Repo.all(...)
  ...
```

This is only neccessary in your channel join functions,
because the channel process does not exist yet when tracing starts.

## Configuration

Above steps will give you a basic installation with standard configuration.
If you want to tweak some settings, here are all the possible configuration options:

| key | default | description |
|-----|---------|-------------|
| `:otp_app` | - | The name of your application. Mainly used to get your application's version. |
| `:api_key` | - | Your project's api key. You can find this on PryIn under "Settings". |
| `:enabled` | - | Whether to forward data to PryIn. Should be set to `true` in all enviroments you want to collect data in. |
| `:env` | - | Name of the current environment. Can be one of `:dev`, `:staging` or `:prod`. |
| `:forward_interval` | 1000 | Duration of forward intervals in milliseconds. During the interval, data is collected and stored locally. At the end of the interval, the data is then forwared to PryIn. |
| `:max_interactions_for_interval` | 100 | Maximum number of traces stored locally during each forward interval. If this limit is reached, new traces will be dropped until data is sent to PryIn and the store is cleared. |
| `:max_tracked_metric_values_for_interval` | 100 | Maximum number of Tracked Metric values stored locally during each forward interval. If this limit is reached, new values will be dropped until data is sent to PryIn and the store is cleared. |
| `:node_name` | `node()` | Name of the current node. BEAM metrics will be grouped under this value. |

## Further reading

You can find more details (about background jobs, custom instrumentation, and a lot more), in PryIn's [FAQs](https://pryin.zendesk.com).
