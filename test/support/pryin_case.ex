defmodule PryIn.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias PryIn.Factory
    end
  end

  setup _tags do
    ensure_test_api_stopped()
    PryIn.InteractionStore.reset_state
    {:ok, _} = PryIn.Api.Test.start_link
    PryIn.Api.Test.subscribe

    :ok
  end

  defp ensure_test_api_stopped do
    case Process.whereis(PryIn.Api.Test) do
      nil -> :ok
      pid ->
        api_ref = Process.monitor(pid)
        Process.exit(pid, :kill)
        receive do
          {:DOWN, ^api_ref, _, _, _} -> :ok
        after
          1_000 -> raise "did not receive PryIn.Api.Test down message after 1s"
        end
    end
  end
end
