defmodule PryIn.EctoLoggerTest do
  use PryIn.Case
  alias PryIn.{EctoLogger, InteractionStore, Interaction}

  @log_entry %Ecto.LogEntry{
    query: "SELECT 1",
    query_time: System.convert_time_unit(50, :micro_seconds, :native),
    decode_time: System.convert_time_unit(100, :micro_seconds, :native),
    queue_time: System.convert_time_unit(200, :micro_seconds, :native),
    source: "user"
  }

  describe "log" do
    test "when no interaction is in the store" do
      log_entry = %{@log_entry | connection_pid: self()}
      assert log_entry == EctoLogger.log(log_entry)
      refute InteractionStore.has_pid?(self())
    end

    test "adds extra data to the interaction in the store" do
      InteractionStore.start_interaction(self(), PryIn.Interaction.new(start_time: 1000))
      log_entry = %{@log_entry | connection_pid: self()}
      assert log_entry == EctoLogger.log(log_entry)
      %{ecto_queries: [data]} = InteractionStore.get_interaction(self())

      assert data.decode_time == 100
      assert data.duration == 350
      assert data.query == "SELECT 1"
      assert data.query_time == 50
      assert data.queue_time == 200
      assert data.source == "user"
      assert data.pid == inspect(self())
      assert data.offset
    end

    test "can handle nil times" do
      InteractionStore.start_interaction(self(), Interaction.new(start_time: 1000))
      log_entry = %{@log_entry | query_time: nil, connection_pid: self()}
      ^log_entry = EctoLogger.log(log_entry)
      %{ecto_queries: [data]} = InteractionStore.get_interaction(self())

      assert data.query_time == 0
      assert data.duration == 300
    end

    test "can handle older ecto versions without source in the log entry" do
      InteractionStore.start_interaction(self(), Interaction.new(start_time: 1000))

      log_entry =
        %{@log_entry | connection_pid: self()}
        |> Map.delete(:source)

      assert log_entry == EctoLogger.log(log_entry)
      %{ecto_queries: [data]} = InteractionStore.get_interaction(self())
      assert data.source == nil
    end

    test "can handle older ecto versions without connection_pid in the log entry" do
      InteractionStore.start_interaction(self(), Interaction.new(start_time: 1000))
      log_entry = Map.delete(@log_entry, :connection_pid)
      assert log_entry == EctoLogger.log(log_entry)
      %{ecto_queries: [data]} = InteractionStore.get_interaction(self())
      assert data.pid == inspect(self())
    end

    test "can handle nil connection_pids" do
      InteractionStore.start_interaction(self(), Interaction.new(start_time: 1000))
      log_entry = %{@log_entry | query_time: nil, connection_pid: nil}
      ^log_entry = EctoLogger.log(log_entry)
      %{ecto_queries: [data]} = InteractionStore.get_interaction(self())

      assert data.query_time == 0
      assert data.duration == 300
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
