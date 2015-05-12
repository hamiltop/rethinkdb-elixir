defmodule DatabaseTest do
  use ExUnit.Case
  use TestConnection
  alias RethinkDB.Record

  setup_all do
    connect
    :ok
  end

  @db_name "query_test_db_1"
  @table_name "query_test_table_1"
  setup do
    q = db_drop(@db_name)
    run(q)

    q = table_drop(@table_name)
    run(q)
    :ok
  end

  test "databases" do
    q = db_create(@db_name)
    %Record{data: %{"dbs_created" => 1}} = run(q)

    q = db_list
    %Record{data: dbs} = run(q)
    assert Enum.member?(dbs, @db_name)

    q = db_drop(@db_name)
    %Record{data: %{"dbs_dropped" => 1}} = run(q)

    q = db_list
    %Record{data: dbs} = TestConnection.run(q)
    assert !Enum.member?(dbs, @db_name)
  end
end
