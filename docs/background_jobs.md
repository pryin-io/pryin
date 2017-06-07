# Tracing background jobs

To trace background jobs, call
`PryIn.CustomTrace.start/2`
when they start and `PryIn.CustomTrace.finish/1` when they finish.

If your background job happens in a `perform` function, this could look like the following:

```elixir
def perform do
  PryIn.CustomTrace.start(group: "Background Jobs", key: "daily_email_worker")
  send_some_emails()
  PryIn.CustomTrace.finish()
end
```

Afterwards, you can find a "Background Jobs" group under "Custom Traces".
All "daily_email_worker" traces will be grouped together, so you can spot trends.

You can also add more specific groups than "Background Jobs", if that makes sense for you.

A "Background Email Jobs" group for example would allow you to get aggregated data about
all your background email jobs as well as more detailed (but still aggregated) data about specific workers.

Tip: You can add your custom trace groups to the navigation sidebar for easier access.
Just click the little start next to the group's name.
