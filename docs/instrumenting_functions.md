# Instrumenting functions

You can wrap any custom code in a call to
`MyApp.Endpoint.instrument` to have it appear in your traces.

If, for example, you are building a star wars app and want to monitor how long it takes to
request a list of planets from an external API, this could look like the following:

```Elixir
  AwesomeApp.Endpoint.instrument :pryin, %{key: "get_star_wars_planets"}, fn ->
    HTTPoison.get("http://swapi.co/api/planets")
  end
```
