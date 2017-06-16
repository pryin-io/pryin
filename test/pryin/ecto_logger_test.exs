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
      @log_entry = EctoLogger.log(@log_entry)
      refute InteractionStore.has_pid?(self())
    end

    test "adds extra data to the interaction in the store" do
      InteractionStore.start_interaction(self(), PryIn.Interaction.new(start_time: 1000))
      @log_entry = EctoLogger.log(@log_entry)
      %{ecto_queries: [data]} = InteractionStore.get_interaction(self())

      assert data.decode_time == 100
      assert data.duration    == 350
      assert data.query       == "SELECT 1"
      assert data.query_time  == 50
      assert data.queue_time  == 200
      assert data.source      == "user"
      assert data.pid         == inspect(self())
      assert data.offset
    end

    test "can handle nil times" do
      InteractionStore.start_interaction(self(), Interaction.new(start_time: 1000))
      log_entry = %{@log_entry | query_time: nil}
      ^log_entry = EctoLogger.log(log_entry)
      %{ecto_queries: [data]} = InteractionStore.get_interaction(self())

      assert data.query_time  == 0
      assert data.duration    == 300
    end

    test "can handle older ecto versions without source in the log entry" do
      InteractionStore.start_interaction(self(), Interaction.new(start_time: 1000))
      log_entry = Map.delete(@log_entry, :source)
      ^log_entry = EctoLogger.log(log_entry)
      %{ecto_queries: [data]} = InteractionStore.get_interaction(self())
      assert data.source == nil
    end
  end
end
