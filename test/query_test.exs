defmodule QueryTest do
  use ExUnit.Case, async: true
  alias RethinkDB.Query
  alias RethinkDB.Record
  alias RethinkDB.Collection
  use RethinkDB.Connection
  import RethinkDB.Query
  require RethinkDB.Lambda

  @table_name "query_test_table_1"
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


  test "make_array" do
    array = [%{"name" => "hello"}, %{"name:" => "world"}]
    q = Query.make_array(array)
    {:ok, %Record{data: data}} = run(q)
    assert Enum.sort(data) == Enum.sort(array)
  end

  test "map" do
    table_query = table(@table_name)

    insert(table_query, [%{name: "Hello"}, %{name: "World"}]) |> run

    {:ok, %Collection{data: data}} = table(@table_name)
      |> map( RethinkDB.Lambda.lambda fn (el) ->
        el[:name] + " " + "with map"
      end) |> run
    assert Enum.sort(data) == ["Hello with map", "World with map"]
  end

  test "filter by map" do
    table_query = table(@table_name)

    insert(table_query, [%{name: "Hello"}, %{name: "World"}]) |> run

    {:ok, %Collection{data: data}} = table(@table_name)
    |> filter(%{name: "Hello"})
    |> run
    assert Enum.map(data, &(&1["name"])) == ["Hello"]
  end

  test "filter by lambda" do
    table_query = table(@table_name)

    insert(table_query, [%{name: "Hello"}, %{name: "World"}]) |> run

    {:ok, %Collection{data: data}} = table(@table_name)
    |> filter(RethinkDB.Lambda.lambda fn (el) ->
      el[:name] == "Hello"
    end)
    |> run
    assert Enum.map(data, &(&1["name"])) == ["Hello"]
  end

  test "nested functions" do
    a = make_array([1,2,3]) |> map(fn (x) ->
      make_array([4,5,6]) |> map(fn (y) ->
        [x, y]
      end)
    end)
    {:ok, %{data: data}} = run(a)
    assert data == [
      [[1,4], [1,5], [1,6]],
      [[2,4], [2,5], [2,6]],
      [[3,4], [3,5], [3,6]]
    ]
  end
end
