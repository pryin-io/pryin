# Instrumenting custom code

You can wrap any custom code in a call to
`PryIn.instrument` to have it appear in your traces.

If, for example, you are building a star wars app and want to monitor how long it takes to
request a list of planets from an external API, this could look like the following:

```Elixir
  require PryIn
  PryIn.instrument("get_star_wars_planets") do
    HTTPoison.get("http://swapi.co/api/planets")
  end
```

Note that you need to `require PryIn` before calling the `instrument` macro.
