defmodule DatabaseTest do
  use ExUnit.Case, async: true
  use RethinkDB.Connection
  import RethinkDB.Query

  alias RethinkDB.Record

  setup_all do
    start_link()
    :ok
  end

  @db_name "db_test_db_1"
  @table_name "db_test_table_1"
  setup do
    q = table_drop(@table_name)
    run(q)
    q = table_create(@table_name)
    run(q)
    on_exit fn ->
      q = table_drop(@table_name)
      run(q)
      db_drop(@db_name) |> run
    end
    :ok
  end

  test "databases" do
    q = db_create(@db_name)
    {:ok, %Record{data: %{"dbs_created" => 1}}} = run(q)

    q = db_list()
    {:ok, %Record{data: dbs}} = run(q)
    assert Enum.member?(dbs, @db_name)

    q = db_drop(@db_name)
    {:ok, %Record{data: %{"dbs_dropped" => 1}}} = run(q)

    q = db_list()
    {:ok, %Record{data: dbs}} = run(q)
    assert !Enum.member?(dbs, @db_name)
  end
end
