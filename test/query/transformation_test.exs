defmodule TransformationTest do
  use ExUnit.Case
  use TestConnection

  alias RethinkDB.Record

  require RethinkDB.Lambda
  import RethinkDB.Lambda

  setup_all do
    connect
    :ok
  end

  @db_name "query_test_db_1"
  @table_name "query_test_table_1"
  setup do
    q = db_drop(@db_name)
    run(q)
    q = db_create(@db_name)
    run(q)
    q = db(@db_name) |> table_create(@table_name)
    run(q)
    :ok
  end

  test "map" do
    %Record{data: data} = map([1,2,3], lambda &(&1 + 1)) |> run
    assert data == [2,3,4]
  end
end
