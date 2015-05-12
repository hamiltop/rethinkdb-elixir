defmodule JoinsTest do
  use ExUnit.Case
  use TestConnection

  alias RethinkDB.Record
  alias RethinkDB.Collection

  setup_all do
    TestConnection.connect
    :ok
  end

  test "inner join arrays" do
    left = [%{a: 1, b: 2}, %{a: 2, b: 3}]
    right = [%{a: 1, c: 4}, %{a: 2, c: 6}]
    q = inner_join(left, right, fn l, r ->
      eq(l[:a], r[:a])
    end)
    %Record{data: data} = run q
    assert data == [%{"left" => %{"a" => 1, "b" => 2}, "right" => %{"a" => 1, "c" => 4}},
                %{"left" => %{"a" => 2, "b" => 3}, "right" => %{"a" => 2, "c" => 6}}]
    %Record{data: data} = q |> zip |> run
    assert data == [%{"a" => 1, "b" => 2, "c" => 4}, %{"a" => 2, "b" => 3, "c" => 6}]
  end

  test "outer join arrays" do
    left = [%{a: 1, b: 2}, %{a: 2, b: 3}]
    right = [%{a: 1, c: 4}]
    q = outer_join(left, right, fn l, r ->
      eq(l[:a], r[:a])
    end)
    %Record{data: data} = run q
    assert data == [%{"left" => %{"a" => 1, "b" => 2}, "right" => %{"a" => 1, "c" => 4}},
                %{"left" => %{"a" => 2, "b" => 3}}]
    %Record{data: data} = q |> zip |> run
    assert data == [%{"a" => 1, "b" => 2, "c" => 4}, %{"a" => 2, "b" => 3}]
  end

  require TestConnection

  test "eq join arrays" do
    TestConnection.with_test_db do

      table_create("test_1") |> run
      table_create("test_2") |> run
      table("test_1") |> insert([%{id: 3, a: 1, b: 2}, %{id: 2, a: 2, b: 3}]) |> run
      table("test_2") |> insert([%{id: 1, c: 4}]) |> run
      q = eq_join(table("test_1"), :a, table("test_2"), %{index: :id})
      %Collection{data: data} = run q
      %Collection{data: data2} = q |> zip |> run
      table_drop("test_1") |> run
      table_drop("test_2") |> run
      assert data == [
        %{"left" => %{"id" => 3, "a" => 1, "b" => 2}, "right" => %{"id" => 1, "c" => 4}}
      ]
      assert data2 == [%{"id" => 1, "a" => 1, "b" => 2, "c" => 4}]
    end
  end
end
