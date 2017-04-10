defmodule PryIn.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias PryIn.Factory
    end
  end

  setup _tags do
    PryIn.InteractionStore.reset_state
    PryIn.Api.Test.start_link
    PryIn.Api.Test.subscribe

    :ok
  end
end
