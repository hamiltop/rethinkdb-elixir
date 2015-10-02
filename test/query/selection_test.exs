defmodule SelectionTest do
  use ExUnit.Case
  use TestConnection

  alias RethinkDB.Record

  require RethinkDB.Lambda
  import RethinkDB.Lambda

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

  test "get all" do
    db_create(@db_name) |> run
    table_drop(@table_name) |> run
    table_create(@table_name) |> run
    table(@table_name) |> insert(%{id: "a", a: 5}) |> run
    table(@table_name) |> insert(%{id: "b", a: 5}) |> run
    data = table(@table_name) |> get_all(["a", "b"]) |> run
    assert Enum.sort(Enum.to_list(data)) == [
      %{"a" => 5, "id" => "a"},
      %{"a" => 5, "id" => "b"}
    ]
  end

  test "get all with index" do
    db_create(@db_name) |> run
    table_drop(@table_name) |> run
    table_create(@table_name) |> run
    table(@table_name) |> insert(%{id: "a", other_id: "c"}) |> run
    table(@table_name) |> insert(%{id: "b", other_id: "d"}) |> run
    table(@table_name) |> index_create("other_id") |> run
    table(@table_name) |> index_wait("other_id") |> run
    data = table(@table_name) |> get_all(["c", "d"], %{index: "other_id"}) |> run
    assert Enum.sort(Enum.to_list(data)) == [
      %{"id" => "a", "other_id" => "c"},
      %{"id" => "b", "other_id" => "d"}
    ]
  end

  test "between" do
    db_create(@db_name) |> run
    table_drop(@table_name) |> run
    table_create(@table_name) |> run
    table(@table_name) |> insert(%{id: "a", a: 5}) |> run
    table(@table_name) |> insert(%{id: "b", a: 5}) |> run
    table(@table_name) |> insert(%{id: "c", a: 5}) |> run
    %RethinkDB.Collection{data: data} = table(@table_name) |> between("b", "d") |> run
    assert Enum.count(data) == 2
  end

  test "filter" do
    db_create(@db_name) |> run
    table_drop(@table_name) |> run
    table_create(@table_name) |> run
    table(@table_name) |> insert(%{id: "a", a: 5}) |> run
    table(@table_name) |> insert(%{id: "b", a: 5}) |> run
    table(@table_name) |> insert(%{id: "c", a: 6}) |> run
    %RethinkDB.Collection{data: data} = table(@table_name) |> filter(%{a: 6}) |> run
    assert Enum.count(data) == 1
    %RethinkDB.Collection{data: data} = table(@table_name) |> filter(
    lambda fn (x) ->
      x["a"] == 5
    end) |> run
    assert Enum.count(data) == 2
  end
end
