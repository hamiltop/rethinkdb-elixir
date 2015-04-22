defmodule QueryTest do
  use ExUnit.Case
  alias Exrethinkdb.Query

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
    [%{"dbs_created" => 1}] = Exrethinkdb.run(context.socket, q)

    q = Query.db_list
    [dbs] = Exrethinkdb.run(context.socket, q)
    assert Enum.member?(dbs, @db_name)

    q = Query.db_drop(@db_name)
    [%{"dbs_dropped" => 1}] = Exrethinkdb.run(context.socket, q)

    q = Query.db_list
    [dbs] = Exrethinkdb.run(context.socket, q)
    assert !Enum.member?(dbs, @db_name)
  end

  test "tables", context do
    q = Query.table_create(@table_name)
    [%{"tables_created" => 1}] = Exrethinkdb.run(context.socket, q)

    q = Query.table_list
    [tables] = Exrethinkdb.run(context.socket, q)
    assert Enum.member?(tables, @table_name)

    q = Query.table_drop(@table_name)
    [%{"tables_dropped" => 1}] = Exrethinkdb.run(context.socket, q)

    q = Query.table_list
    [tables] = Exrethinkdb.run(context.socket, q)
    assert !Enum.member?(tables, @table_name)

    q = Query.table_create(@table_name, %{primary_key: "not_id"})
    [result] = Exrethinkdb.run(context.socket, q)
    %{"config_changes" => [%{"new_val" => %{"primary_key" => primary_key}}]} = result
    assert primary_key == "not_id"
  end

  test "tables with specific database", context do
    q = Query.db_create(@db_name)
    [%{"dbs_created" => 1}] = Exrethinkdb.run(context.socket, q)
    db_query = Query.db(@db_name)

    q = Query.table_create(db_query, @table_name)
    [%{"tables_created" => 1}] = Exrethinkdb.run(context.socket, q)

    q = Query.table_list(db_query)
    [tables] = Exrethinkdb.run(context.socket, q)
    assert Enum.member?(tables, @table_name)

    q = Query.table_drop(db_query, @table_name)
    [%{"tables_dropped" => 1}] = Exrethinkdb.run(context.socket, q)

    q = Query.table_list(db_query)
    [tables] = Exrethinkdb.run(context.socket, q)
    assert !Enum.member?(tables, @table_name)

    q = Query.table_create(db_query, @table_name, %{primary_key: "not_id"})
    [result] = Exrethinkdb.run(context.socket, q)
    %{"config_changes" => [%{"new_val" => %{"primary_key" => primary_key}}]} = result
    assert primary_key == "not_id"
  end
end
