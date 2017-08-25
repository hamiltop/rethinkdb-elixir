defmodule TableDBTest do
  use ExUnit.Case, async: true
  use RethinkDB.Connection
  import RethinkDB.Query

  alias RethinkDB.Record

  setup_all do
    start_link()
    :ok
  end

  @db_name "table_db_test_db_1"
  @table_name "table_db_test_table_1"

  test "tables with specific database" do
    db_create(@db_name) |> run
    on_exit fn ->
      db_drop(@db_name) |> run
    end

    q = db(@db_name) |> table_create(@table_name)
    {:ok, %Record{data: %{"tables_created" => 1}}} = run q

    q = db(@db_name) |> table_list
    {:ok, %Record{data: tables}} = run q
    assert Enum.member?(tables, @table_name)

    q = db(@db_name) |> table_drop(@table_name)
    {:ok, %Record{data: %{"tables_dropped" => 1}}} = run q

    q = db(@db_name) |> table_list
    {:ok, %Record{data: tables}} = run q
    assert !Enum.member?(tables, @table_name)

    q = db(@db_name) |> table_create(@table_name, primary_key: "not_id")
    {:ok, %Record{data: result}} = run q
    %{"config_changes" => [%{"new_val" => %{"primary_key" => primary_key}}]} = result
    assert primary_key == "not_id"
  end
end
