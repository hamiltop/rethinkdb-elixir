defmodule SelectionTest do
  use ExUnit.Case, async: true
  use RethinkDB.Connection
  import RethinkDB.Query

  alias RethinkDB.Record

  require RethinkDB.Lambda
  import RethinkDB.Lambda

  @table_name "selection_test_table_1"
  setup_all do
    start_link()
    table_create(@table_name) |> run
    on_exit fn ->
      start_link()
      table_drop(@table_name) |> run
    end
    :ok
  end

  setup do
    table(@table_name) |> delete |> run
    :ok
  end

  test "get" do
    table(@table_name) |> insert(%{id: "a", a: 5}) |> run
    {:ok, %Record{data: data}} = table(@table_name) |> get("a") |> run
    assert data == %{"a" => 5, "id" => "a"}
  end

  test "get all" do
    table(@table_name) |> insert(%{id: "a", a: 5}) |> run
    table(@table_name) |> insert(%{id: "b", a: 5}) |> run
    {:ok, data} = table(@table_name) |> get_all(["a", "b"]) |> run
    assert Enum.sort(Enum.to_list(data)) == [
      %{"a" => 5, "id" => "a"},
      %{"a" => 5, "id" => "b"}
    ]
  end

  test "get all with index" do
    table(@table_name) |> insert(%{id: "a", other_id: "c"}) |> run
    table(@table_name) |> insert(%{id: "b", other_id: "d"}) |> run
    table(@table_name) |> index_create("other_id") |> run
    table(@table_name) |> index_wait("other_id") |> run
    {:ok, data} = table(@table_name) |> get_all(["c", "d"], index: "other_id") |> run
    assert Enum.sort(Enum.to_list(data)) == [
      %{"id" => "a", "other_id" => "c"},
      %{"id" => "b", "other_id" => "d"}
    ]
  end

  test "get all should be able to accept an empty list" do
    {:ok, result} = table(@table_name) |> get_all([]) |> run
    assert result.data == []
  end

  test "between" do
    table(@table_name) |> insert(%{id: "a", a: 5}) |> run
    table(@table_name) |> insert(%{id: "b", a: 5}) |> run
    table(@table_name) |> insert(%{id: "c", a: 5}) |> run
    {:ok, %RethinkDB.Collection{data: data}} = table(@table_name) |> between("b", "d") |> run
    assert Enum.count(data) == 2
    {:ok, %RethinkDB.Collection{data: data}} = table(@table_name) |> between(minval(), maxval()) |> run
    assert Enum.count(data) == 3
  end

  test "filter" do
    table(@table_name) |> insert(%{id: "a", a: 5}) |> run
    table(@table_name) |> insert(%{id: "b", a: 5}) |> run
    table(@table_name) |> insert(%{id: "c", a: 6}) |> run
    {:ok, %RethinkDB.Collection{data: data}} = table(@table_name) |> filter(%{a: 6}) |> run
    assert Enum.count(data) == 1
    {:ok, %RethinkDB.Collection{data: data}} = table(@table_name) |> filter(
    lambda fn (x) ->
      x["a"] == 5
    end) |> run
    assert Enum.count(data) == 2
  end
end
