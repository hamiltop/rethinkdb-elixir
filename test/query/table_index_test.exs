defmodule TableIndexTest do
  use ExUnit.Case, async: true
  use RethinkDB.Connection
  import RethinkDB.Query
  alias RethinkDB.Record

  setup_all do
    start_link()
    :ok
  end

  @table_name "table_index_test_table_1"
  setup do
    table_create(@table_name) |> run
    on_exit fn ->
      table_drop(@table_name) |> run
    end
    :ok
  end

  test "indexes" do
    {:ok, %Record{data: data}} = table(@table_name) |> index_create("hello") |> run
    assert data == %{"created" => 1}
    {:ok, %Record{data: data}} = table(@table_name) |> index_wait("hello") |> run
    assert [
      %{"function" => _, "geo" => false, "index" => "hello",
        "multi" => false, "outdated" => false,"ready" => true}
      ] = data
    {:ok, %Record{data: data}} = table(@table_name) |> index_status("hello") |> run
    assert [
      %{"function" => _, "geo" => false, "index" => "hello",
        "multi" => false, "outdated" => false,"ready" => true}
      ] = data
    {:ok, %Record{data: data}} = table(@table_name) |> index_list |> run
    assert data == ["hello"]
    table(@table_name) |> index_rename("hello", "goodbye") |> run
    {:ok, %Record{data: data}} = table(@table_name) |> index_list |> run
    assert data == ["goodbye"]
    table(@table_name) |> index_drop("goodbye") |> run
    {:ok, %Record{data: data}} = table(@table_name) |> index_list |> run
    assert data == []
  end
end
