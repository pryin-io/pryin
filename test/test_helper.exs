ExUnit.start()
{:ok, _} = Application.ensure_all_started(:ex_machina)
{:ok, _} = PryIn.TestEndpoint.start_link()
