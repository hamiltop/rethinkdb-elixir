defmodule QueryTest do
  use ExUnit.Case
  alias Exrethinkdb.Query
  alias Exrethinkdb.Record
  alias Exrethinkdb.Collection
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

  test "tables" do
    q = Query.table_create(@table_name)
    %Record{data: %{"tables_created" => 1}} = TestConnection.run(q)

    q = Query.table_list
    %Record{data: tables} = TestConnection.run(q)
    assert Enum.member?(tables, @table_name)

    q = Query.table_drop(@table_name)
    %Record{data: %{"tables_dropped" => 1}} = TestConnection.run(q)

    q = Query.table_list
    %Record{data: tables} = TestConnection.run(q)
    assert !Enum.member?(tables, @table_name)

    q = Query.table_create(@table_name, %{primary_key: "not_id"})
    %Record{data: result} = TestConnection.run(q)
    %{"config_changes" => [%{"new_val" => %{"primary_key" => primary_key}}]} = result
    assert primary_key == "not_id"
  end

  test "tables with specific database" do
    q = db_create(@db_name)
    %Record{data: %{"dbs_created" => 1}} = TestConnection.run(q)
    db_query = Query.db(@db_name)

    q = Query.table_create(db_query, @table_name)
    %Record{data: %{"tables_created" => 1}} = TestConnection.run(q)

    q = Query.table_list(db_query)
    %Record{data: tables} = TestConnection.run(q)
    assert Enum.member?(tables, @table_name)

    q = Query.table_drop(db_query, @table_name)
    %Record{data: %{"tables_dropped" => 1}} = TestConnection.run(q)

    q = Query.table_list(db_query)
    %Record{data: tables} = TestConnection.run(q)
    assert !Enum.member?(tables, @table_name)

    q = Query.table_create(db_query, @table_name, %{primary_key: "not_id"})
    %Record{data: result} = TestConnection.run(q)
    %{"config_changes" => [%{"new_val" => %{"primary_key" => primary_key}}]} = result
    assert primary_key == "not_id"
  end

  test "make_array" do
    array = [%{"name" => "hello"}, %{"name:" => "world"}]
    q = Query.make_array(array)
    %Record{data: data} = TestConnection.run(q)
    assert Enum.sort(data) == Enum.sort(array)
  end

  test "insert" do
    q = Query.table_create(@table_name)
    %Record{data: %{"tables_created" => 1}} = TestConnection.run(q)
    table_query = Query.table(@table_name)

    q = insert(table_query, %{name: "Hello", attr: "World"})
    %Record{data: %{"inserted" => 1, "generated_keys" => [key]}} = TestConnection.run(q)

    %Collection{data: [%{"id" => ^key, "name" => "Hello", "attr" => "World"}]} = TestConnection.run(table_query)
  end

  test "insert multiple" do
    q = Query.table_create(@table_name)
    %Record{data: %{"tables_created" => 1}} = TestConnection.run(q)
    table_query = Query.table(@table_name)

    q = insert(table_query, [%{name: "Hello"}, %{name: "World"}])
    %Record{data: %{"inserted" => 2}} = TestConnection.run(q)

    %Collection{data: data} = TestConnection.run(table_query)
    assert Enum.map(data, &(&1["name"])) |> Enum.sort == ["Hello", "World"]
  end

  test "map" do
    require Exrethinkdb.Lambda

    q = Query.table_create(@table_name)
    %Record{data: %{"tables_created" => 1}} = TestConnection.run(q)
    table_query = Query.table(@table_name)

    insert(table_query, [%{name: "Hello"}, %{name: "World"}]) |> TestConnection.run

    %Collection{data: data} = Query.table(@table_name)
      |> Query.map( Exrethinkdb.Lambda.lambda fn (el) ->
        el[:name] + " " + "with map"
      end) |> TestConnection.run
    assert Enum.sort(data) == ["Hello with map", "World with map"]
  end

  test "filter by map" do
    require Exrethinkdb.Lambda

    q = Query.table_create(@table_name)
    %Record{data: %{"tables_created" => 1}} = TestConnection.run(q)
    table_query = Query.table(@table_name)

    insert(table_query, [%{name: "Hello"}, %{name: "World"}]) |> TestConnection.run

    %Collection{data: data} = Query.table(@table_name)
    |> Query.filter(%{name: "Hello"})
    |> TestConnection.run
    assert Enum.map(data, &(&1["name"])) == ["Hello"]
  end

  test "filter by lambda" do
    require Exrethinkdb.Lambda

    q = Query.table_create(@table_name)
    %Record{data: %{"tables_created" => 1}} = TestConnection.run(q)
    table_query = Query.table(@table_name)

    insert(table_query, [%{name: "Hello"}, %{name: "World"}]) |> TestConnection.run

    %Collection{data: data} = Query.table(@table_name)
    |> Query.filter(Exrethinkdb.Lambda.lambda fn (el) ->
      el[:name] == "Hello"
    end)
    |> TestConnection.run
    assert Enum.map(data, &(&1["name"])) == ["Hello"]
  end

  test "nested functions" do
    import Query
    a = make_array([1,2,3]) |> map(fn (x) ->
      make_array([4,5,6]) |> map(fn (y) ->
        [x, y]
      end)
    end)
    %{data: data} = TestConnection.run(a)
    assert data == [
      [[1,4], [1,5], [1,6]],
      [[2,4], [2,5], [2,6]],
      [[3,4], [3,5], [3,6]]
    ]
  end
end
