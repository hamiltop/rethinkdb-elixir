defmodule QueryTest do
  use ExUnit.Case
  alias Exrethinkdb.Query
  alias Exrethinkdb.Record
  alias Exrethinkdb.Collection

  setup_all do
    socket = Exrethinkdb.connect
    {:ok, %{socket: socket}}
  end

  @db_name "query_test_db_1"
  @table_name "query_test_table_1"
  setup context do
    q = Query.db_drop(@db_name)
    Exrethinkdb.run(context.socket, q)

    q = Query.table_drop(@table_name)
    Exrethinkdb.run(context.socket, q)
    {:ok, context}
  end

  test "databases", context do
    q = Query.db_create(@db_name)
    %Record{data: %{"dbs_created" => 1}} = Exrethinkdb.run(context.socket, q)

    q = Query.db_list
    %Record{data: dbs} = Exrethinkdb.run(context.socket, q)
    assert Enum.member?(dbs, @db_name)

    q = Query.db_drop(@db_name)
    %Record{data: %{"dbs_dropped" => 1}} = Exrethinkdb.run(context.socket, q)

    q = Query.db_list
    %Record{data: dbs} = Exrethinkdb.run(context.socket, q)
    assert !Enum.member?(dbs, @db_name)
  end

  test "tables", context do
    q = Query.table_create(@table_name)
    %Record{data: %{"tables_created" => 1}} = Exrethinkdb.run(context.socket, q)

    q = Query.table_list
    %Record{data: tables} = Exrethinkdb.run(context.socket, q)
    assert Enum.member?(tables, @table_name)

    q = Query.table_drop(@table_name)
    %Record{data: %{"tables_dropped" => 1}} = Exrethinkdb.run(context.socket, q)

    q = Query.table_list
    %Record{data: tables} = Exrethinkdb.run(context.socket, q)
    assert !Enum.member?(tables, @table_name)

    q = Query.table_create(@table_name, %{primary_key: "not_id"})
    %Record{data: result} = Exrethinkdb.run(context.socket, q)
    %{"config_changes" => [%{"new_val" => %{"primary_key" => primary_key}}]} = result
    assert primary_key == "not_id"
  end

  test "tables with specific database", context do
    q = Query.db_create(@db_name)
    %Record{data: %{"dbs_created" => 1}} = Exrethinkdb.run(context.socket, q)
    db_query = Query.db(@db_name)

    q = Query.table_create(db_query, @table_name)
    %Record{data: %{"tables_created" => 1}} = Exrethinkdb.run(context.socket, q)

    q = Query.table_list(db_query)
    %Record{data: tables} = Exrethinkdb.run(context.socket, q)
    assert Enum.member?(tables, @table_name)

    q = Query.table_drop(db_query, @table_name)
    %Record{data: %{"tables_dropped" => 1}} = Exrethinkdb.run(context.socket, q)

    q = Query.table_list(db_query)
    %Record{data: tables} = Exrethinkdb.run(context.socket, q)
    assert !Enum.member?(tables, @table_name)

    q = Query.table_create(db_query, @table_name, %{primary_key: "not_id"})
    %Record{data: result} = Exrethinkdb.run(context.socket, q)
    %{"config_changes" => [%{"new_val" => %{"primary_key" => primary_key}}]} = result
    assert primary_key == "not_id"
  end

  test "make_array", context do
    array = [%{"name" => "hello"}, %{"name:" => "world"}]
    q = Query.make_array(array)
    %Record{data: data} = Exrethinkdb.run(context.socket, q)
    assert Enum.sort(data) == Enum.sort(array)
  end

  test "insert", context do
    q = Query.table_create(@table_name)
    %Record{data: %{"tables_created" => 1}} = Exrethinkdb.run(context.socket, q)
    table_query = Query.table(@table_name)

    q = Query.insert(table_query, %{name: "Hello", attr: "World"})
    %Record{data: %{"inserted" => 1, "generated_keys" => [key]}} = Exrethinkdb.run(context.socket, q)

    %Collection{data: [%{"id" => ^key, "name" => "Hello", "attr" => "World"}]} = Exrethinkdb.run(context.socket, table_query)
  end

  test "insert multiple", context do
    q = Query.table_create(@table_name)
    %Record{data: %{"tables_created" => 1}} = Exrethinkdb.run(context.socket, q)
    table_query = Query.table(@table_name)

    q = Query.insert(table_query, [%{name: "Hello"}, %{name: "World"}])
    %Record{data: %{"inserted" => 2}} = Exrethinkdb.run(context.socket, q)

    %Collection{data: data} = Exrethinkdb.run(context.socket, table_query)
    assert Enum.map(data, &(&1["name"])) |> Enum.sort == ["Hello", "World"]
  end

  test "map", context do
    require Exrethinkdb.Lambda

    q = Query.table_create(@table_name)
    %Record{data: %{"tables_created" => 1}} = Exrethinkdb.run(context.socket, q)
    table_query = Query.table(@table_name)

    Query.insert(table_query, [%{name: "Hello"}, %{name: "World"}]) |> Exrethinkdb.run

    %Collection{data: data} = Query.table(@table_name)
      |> Query.map( Exrethinkdb.Lambda.lambda fn (el) ->
        Query.bracket(el, :name) + " " + "with map"
      end) |> Exrethinkdb.run
    assert Enum.sort(data) == ["Hello with map", "World with map"]
  end

  test "filter by map", context do
    require Exrethinkdb.Lambda

    q = Query.table_create(@table_name)
    %Record{data: %{"tables_created" => 1}} = Exrethinkdb.run(context.socket, q)
    table_query = Query.table(@table_name)

    Query.insert(table_query, [%{name: "Hello"}, %{name: "World"}]) |> Exrethinkdb.run

    %Collection{data: data} = Query.table(@table_name)
    |> Query.filter(%{name: "Hello"})
    |> Exrethinkdb.run
    assert Enum.map(data, &(&1["name"])) == ["Hello"]
  end

  test "filter by lambda", context do
    require Exrethinkdb.Lambda

    q = Query.table_create(@table_name)
    %Record{data: %{"tables_created" => 1}} = Exrethinkdb.run(context.socket, q)
    table_query = Query.table(@table_name)

    Query.insert(table_query, [%{name: "Hello"}, %{name: "World"}]) |> Exrethinkdb.run

    %Collection{data: data} = Query.table(@table_name)
    |> Query.filter(Exrethinkdb.Lambda.lambda fn (el) ->
      Query.bracket(el, :name) = "Hello"
    end)
    |> Exrethinkdb.run
    assert Enum.map(data, &(&1["name"])) == ["Hello"]
  end
end
