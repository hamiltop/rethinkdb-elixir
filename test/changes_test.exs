defmodule ChangesTest do
  use ExUnit.Case
  alias RethinkDB.Feed
  use TestConnection

  setup_all do
    socket = connect
    {:ok, %{socket: socket}}
  end

  @db_name "query_test_db_1"
  @table_name "query_test_table_1"
  setup context do
    q = db_drop(@db_name)
    run(q)

    q = table_drop(@table_name)
    run(q)
    {:ok, context}
  end

  test "changes" do
    q = db_create(@db_name)
    run(q)
    q = table_create(@table_name)
    run(q)

    q = table(@table_name) |> changes
    changes = %Feed{} = run(q)
    t = Task.async fn ->
      next(changes)
    end
    data = %{"test" => "data"}
    q = table(@table_name) |> insert(data)
    res = run(q)
    expected = res.data["id"]
    changes = Task.await(t) 
    ^expected = changes.data |> hd |> Map.get("id")

    # test Enumerable
    t = Task.async fn ->
      changes |> Enum.take(5)  
    end
    1..6 |> Enum.each fn _ ->
      q = table(@table_name) |> insert(data)
      run(q)
    end
    data = Task.await(t) 
    5 = Enum.count(data)
  end
end
