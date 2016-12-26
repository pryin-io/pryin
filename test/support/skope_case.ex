defmodule Skope.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
    end
  end

  setup _tags do
    Skope.InteractionStore.reset_state
    Skope.Api.Test.start_link
    Skope.Api.Test.subscribe

    :ok
  end
end
