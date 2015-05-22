defmodule SelectionTest do
  use ExUnit.Case
  use TestConnection

  alias RethinkDB.Record

  setup_all do
    TestConnection.connect
    :ok
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

  test "get" do
    db_create(@db_name) |> run
    table_create(@table_name) |> run
    table(@table_name) |> insert(%{id: "a", a: 5}) |> run
    %Record{data: data} = table(@table_name) |> get("a") |> run
    assert data == %{"a" => 5, "id" => "a"}
  end
end
