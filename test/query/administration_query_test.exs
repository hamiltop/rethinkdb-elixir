defmodule AdministrationQueryTest do
  use ExUnit.Case, async: false
  use RethinkDB.Connection
  import RethinkDB.Query

  @table_name "administration_table_1"

  setup_all do
    start_link()

    db_create("test") |> run
    table_create(@table_name) |> run

    on_exit fn ->
      start_link()

      db_drop("test") |> run
    end

    :ok
  end

  setup do
    on_exit fn ->
      table(@table_name) |> delete |> run
    end

    :ok
  end

  test "config" do
    {:ok, r} = table(@table_name) |> config |> run
    assert %RethinkDB.Record{data: %{"db" => "test"}} = r
  end

  test "rebalance" do
    {:ok, r} = table(@table_name) |> rebalance |> run
    assert %RethinkDB.Record{data: %{"rebalanced" => _}} = r
  end

  test "reconfigure" do
    {:ok, r} = table(@table_name) |> reconfigure(shards: 1, dry_run: true, replicas: 1) |> run
    assert %RethinkDB.Record{data: %{"reconfigured" => _}} = r
  end

  test "status" do
    {:ok, r} = table(@table_name) |> status |> run
    assert %RethinkDB.Record{data: %{"name" => @table_name}} = r
  end

  test "wait" do
    {:ok, r} = table(@table_name) |> wait(wait_for: :ready_for_writes) |> run
    assert %RethinkDB.Record{data: %{"ready" => 1}} = r
  end
end
