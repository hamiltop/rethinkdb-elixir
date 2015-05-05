defmodule ChangesTest do
  use ExUnit.Case
  alias Exrethinkdb.Query
  alias Exrethinkdb.Feed

  setup_all do
    socket = TestConnection.connect
    {:ok, %{socket: socket}}
  end

  @db_name "query_test_db_1"
  @table_name "query_test_table_1"
  setup context do
    q = Query.db_drop(@db_name)
    TestConnection.run(q)

    q = Query.table_drop(@table_name)
    TestConnection.run(q)
    {:ok, context}
  end

  test "changes" do
    q = Query.db_create(@db_name)
    TestConnection.run(q)
    q = Query.table_create(@table_name)
    TestConnection.run(q)

    q = Query.table(@table_name) |> Query.changes
    changes = %Feed{} = TestConnection.run(q)
    t = Task.async fn ->
      TestConnection.next(changes)
    end
    data = %{"test" => "data"}
    q = Query.table(@table_name) |> Query.insert(data)
    res = TestConnection.run(q)
    expected = res.data["id"]
    changes = Task.await(t) 
    ^expected = changes.data |> hd |> Map.get("id")

    # test Enumerable
    t = Task.async fn ->
      changes |> Enum.take(5)  
    end
    1..6 |> Enum.each fn _ ->
      q = Query.table(@table_name) |> Query.insert(data)
      TestConnection.run(q)
    end
    data = Task.await(t) 
    5 = Enum.count(data)
  end
end
