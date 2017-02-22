# config/.credo.exs
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "src/", "web/", "apps/"],
        excluded: []
      },
      checks: [
        {Credo.Check.Refactor.PipeChainStart, false},
        {Credo.Check.Readability.Specs, false},
        {Credo.Check.Refactor.VariableRebinding, false},
      ]
    }
  ]
}
