defmodule PryIn.GenServer do
  @moduledoc """
  Allows tracking data about a GenServer process.

  To use, first define functions that receive the GenServer's state and return the data you want to track.
  Then `use` PryIn.GenServer in your GenServer module and add configuration.

  ### Value functions

  For every metric you want to track, define a function.
  That function will receive the GenServer's state as argument
  and should return a tuple of `:ok`, the current value of the metric,
  and the new state of the GenServer.

  The current value of the metric should be a number.

  The new state will replace your GenServer's state.
  In many cases this will just be the state passed into your function,
  but if you want to keep track of some value that gets reset every
  time you forward it to PryIn, you can do that here.

  Example:
  ```elixir
  def queue_length(state) do
    {:ok, length(state.queue), state}
  end
  ```

  ### Configuration

  To periodically call your value functions and forward the metrics,
  add `use PryIn.GenServer` with the correct configuration to your GenServer's module.

  The `values` configuration option takes a map,
  which should have one entry for every value function.
  That entry should have the name of your metric as key,
  and a tuple with a reference to your function and the period in milliseconds as value.


  Example:
  ```elixir
  defmodule MyGenServer do
    use GenServer
    use PryIn.GenServer, values: %{
      "ImportQueue length" =>  {&MyGenServer.queue_length/1, 5_000}
    }
    ...
  ```
  """

  defmacro __using__(opts) do
    quote location: :keep do
      @before_compile PryIn.GenServer
      @pryin_tracked_value_funs unquote(opts[:values])
    end
  end

  defmacro __before_compile__(_env) do
    quote location: :keep do
      defoverridable init: 1, handle_info: 2

      def init(args) do
        for {name, {_, interval}} <- @pryin_tracked_value_funs do
          Process.send_after(self(), {:track_pryin_metric, name}, interval)
        end

        super(args)
      end

      def handle_info({:track_pryin_metric, name}, state) do
        {fun, interval} = Map.fetch!(@pryin_tracked_value_funs, name)
        {:ok, value, state} = fun.(state)
        PryIn.track_metric(name, value)

        Process.send_after(self(), {:track_pryin_metric, name}, interval)
        {:noreply, state}
      end
    end
  end
end
