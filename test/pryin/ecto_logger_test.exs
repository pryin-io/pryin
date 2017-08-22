defmodule PryIn.EctoLoggerTest do
  use PryIn.Case
  alias PryIn.{EctoLogger, InteractionStore, Interaction}

  @log_entry %Ecto.LogEntry{
    query: "SELECT 1",
    query_time: System.convert_time_unit(50, :micro_seconds, :native),
    decode_time: System.convert_time_unit(100, :micro_seconds, :native),
    queue_time: System.convert_time_unit(200, :micro_seconds, :native),
    source: "user",
  }

  describe "log" do
    test "when no interaction is in the store" do
      log_entry = %{@log_entry | connection_pid: self()}
      assert log_entry == EctoLogger.log(log_entry)
      refute InteractionStore.has_pid?(self())
    end

    property "adds extra data to the interaction in the store" do
      check all query <- PropertyHelpers.non_empty_string(),
        query_micros <- one_of([int(0..60_000_000), nil]),
        queue_micros <- one_of([int(0..60_000_000), nil]),
        decode_micros <- one_of([int(0..60_000_000), nil]),
        source <- PropertyHelpers.non_empty_string(),
        connection_pid <- one_of([nil, constant(self())])do
        InteractionStore.reset_state()
        InteractionStore.start_interaction(self(), PryIn.Interaction.new(start_time: 1000))

        log_entry = %{@log_entry | connection_pid: connection_pid,
                      query: query,
                      query_time: if(query_micros, do: System.convert_time_unit(query_micros, :micro_seconds, :native)),
                      queue_time: if(queue_micros, do: System.convert_time_unit(queue_micros, :micro_seconds, :native)),
                      decode_time: if(decode_micros, do: System.convert_time_unit(decode_micros, :micro_seconds, :native)),
                      source: source}
        assert log_entry == EctoLogger.log(log_entry)
        %{ecto_queries: [data]} = InteractionStore.get_interaction(self())

        duration = ([decode_micros, query_micros, queue_micros] |> Enum.reject(&is_nil/1) |> Enum.sum)
        assert data.duration    == duration
        assert data.query       == query
        assert data.query_time  == if query_micros, do: query_micros, else: 0
        assert data.queue_time  == if queue_micros, do: queue_micros, else: 0
        assert data.decode_time  == if decode_micros, do: decode_micros, else: 0
        assert data.source      == source
        assert data.pid         == inspect(self())
        assert data.offset
      end
    end

    test "can handle older ecto versions without source in the log entry" do
      InteractionStore.start_interaction(self(), Interaction.new(start_time: 1000))
      log_entry = %{@log_entry | connection_pid: self()}
      |> Map.delete(:source)
      assert log_entry == EctoLogger.log(log_entry)
      %{ecto_queries: [data]} = InteractionStore.get_interaction(self())
      assert data.source == nil
    end

    test "can handle older ecto versions without connection_pid in the log entry" do
      InteractionStore.start_interaction(self(), Interaction.new(start_time: 1000))
      log_entry =  Map.delete(@log_entry, :connection_pid)
      assert log_entry == EctoLogger.log(log_entry)
      %{ecto_queries: [data]} = InteractionStore.get_interaction(self())
      assert data.pid == inspect(self())
    end

    test "can handle log entries with functions as query" do
      InteractionStore.start_interaction(self(), PryIn.Interaction.new(start_time: 1000))
      query_function = fn %Ecto.LogEntry{} = entry ->
        "QUERY #{entry.source}"
      end
      log_entry = %{@log_entry | connection_pid: self(), query: query_function}
      assert log_entry == EctoLogger.log(log_entry)
      %{ecto_queries: [data]} = InteractionStore.get_interaction(self())

      assert data.query == "QUERY user"
    end
  end
end
