defmodule QueryTest do
  use ExUnit.Case
  alias Exrethinkdb.Query
  alias Exrethinkdb.Record

  setup_all do
    socket = Exrethinkdb.local_connection
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
end
