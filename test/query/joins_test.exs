defmodule JoinsTest do
  use ExUnit.Case, async: true
  use RethinkDB.Connection
  import RethinkDB.Query

  alias RethinkDB.Record
  alias RethinkDB.Collection

  require RethinkDB.Lambda
  import RethinkDB.Lambda

  @table_name "joins_test_table_1"
  setup_all do
    start_link()
    table_create(@table_name) |> run
    on_exit fn ->
      start_link()
      table_drop(@table_name) |> run
    end
    :ok
  end

  setup do
    table(@table_name) |> delete |> run
    :ok
  end

  test "inner join arrays" do
    left = [%{a: 1, b: 2}, %{a: 2, b: 3}]
    right = [%{a: 1, c: 4}, %{a: 2, c: 6}]
    q = inner_join(left, right,lambda fn l, r ->
      l[:a] == r[:a]
    end)
    {:ok, %Record{data: data}} = run q
    assert data == [%{"left" => %{"a" => 1, "b" => 2}, "right" => %{"a" => 1, "c" => 4}},
                %{"left" => %{"a" => 2, "b" => 3}, "right" => %{"a" => 2, "c" => 6}}]
    {:ok, %Record{data: data}} = q |> zip |> run
    assert data == [%{"a" => 1, "b" => 2, "c" => 4}, %{"a" => 2, "b" => 3, "c" => 6}]
  end

  test "outer join arrays" do
    left = [%{a: 1, b: 2}, %{a: 2, b: 3}]
    right = [%{a: 1, c: 4}]
    q = outer_join(left, right, lambda fn l, r ->
      l[:a] == r[:a]
    end)
    {:ok, %Record{data: data}} = run q
    assert data == [%{"left" => %{"a" => 1, "b" => 2}, "right" => %{"a" => 1, "c" => 4}},
                %{"left" => %{"a" => 2, "b" => 3}}]
    {:ok, %Record{data: data}} = q |> zip |> run
    assert data == [%{"a" => 1, "b" => 2, "c" => 4}, %{"a" => 2, "b" => 3}]
  end

  test "eq join arrays" do
    table_create("test_1") |> run
    table_create("test_2") |> run
    table("test_1") |> insert([%{id: 3, a: 1, b: 2}, %{id: 2, a: 2, b: 3}]) |> run
    table("test_2") |> insert([%{id: 1, c: 4}]) |> run
    q = eq_join(table("test_1"), :a, table("test_2"), index: :id)
    {:ok, %Collection{data: data}} = run q
    {:ok, %Collection{data: data2}} = q |> zip |> run
    table_drop("test_1") |> run
    table_drop("test_2") |> run
    assert data == [
      %{"left" => %{"id" => 3, "a" => 1, "b" => 2}, "right" => %{"id" => 1, "c" => 4}}
    ]
    assert data2 == [%{"id" => 1, "a" => 1, "b" => 2, "c" => 4}]
  end
end
