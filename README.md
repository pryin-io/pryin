# PryIn


[PryIn](https://pryin.io) is a performance metrics platform for your Phoenix application.

## Installation

  1. Sign up for a [PryIn](https://pryin.io) account and create a new project there.
  2. Add `pryin` to your dependencies and applications list in `mix.exs`:

    ```elixir
    def applications do
      [..., :pryin]
    end
    ...
    def deps do
      [{:pryin, "~> 0.1.0"}]
    end
    ```

  3. Add global configuration for the pryin app in `config/config.exs`:

    ```elixir
    config :pryin,
      api_key: "your_secret_api_key",
      enabled: false,
      env: "dev"
    ```

  4. Enable PryIn in the environments you want to collect metrics for.
    If you want to collect data for the production environment, for example,
    add the following to `config/prod.exs`:

    ```elixir
    config :pryin,
      enabled: true,
      env: "prod"
    ```

    Possible values for `env` are `dev`, `staging` or `prod`.

  5. Add the PryIn plug to your application's endpoint (`lib/my_app/endpoint.ex`) just before the router plug:

    ```elixir
    ...
    plug PryIn.Plug
    plug MyApp.Router

    ```

  6. Add the Ecto logger in `config/config.exs`:

    ```elixir
    ...
    config :my_app, MyApp.Repo,
      loggers: [PryIn.EctoLogger, Ecto.LogEntry]
    ```

  7. Add the PryIn instrumenter in `config/config.exs`:

    ```elixir
    ...
    config :my_app, MyApp.Endpoint,
      ...,
      instrumenters: [PryIn.Instrumenter]
    ```

  8. If you want to measure the runtime of custom code, wrap it in an instrumented function.
    To track how long calls to the Foobar Api take, for example, do the following:

    ```elixir
    defmodule MyApp.SomeController do
      require MyApp.Endpoint
      ...

      def my_action(conn, params) do
        ...
        api_call_result =
          MyApp.Endpoint.instrument(:pryin, %{key: "foobar_api_call"}, fn ->
            FoobarApi.call(some_arguments)
        end)
        ...
      end

      ...
    end
    ```

    After this, Foobar Api call will be tracked under the key `foobar_api_call`.
    Note that you need to `require` your endpoint before invoking the `instrument` macro.
