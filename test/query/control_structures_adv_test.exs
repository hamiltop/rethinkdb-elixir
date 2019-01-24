defmodule ControlStructuresAdvTest do
  use ExUnit.Case, async: false
  use RethinkDB.Connection
  import RethinkDB.Query

  alias RethinkDB.Collection

  @table_name "control_test_table_1"
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
    table(@table_name) |> delete |> run
    :ok
  end

  test "for_each" do
    table_query = table(@table_name)
    q = [1,2,3] |> for_each(fn(x) ->
      table_query |> insert(%{a: x})
    end)
    run q
    {:ok, %Collection{data: data}} = run table_query
    assert Enum.count(data) == 3
  end
end
