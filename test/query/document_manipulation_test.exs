defmodule DocumentManipulationTest do
  use ExUnit.Case, async: true
  use RethinkDB.Connection
  import RethinkDB.Query

  alias RethinkDB.Record

  setup_all do
    start_link()
    :ok
  end

  test "pluck" do
    {:ok, %Record{data: data}} = [
      %{a: 5, b: 6, c: 3},
      %{a: 7, b: 8}
    ] |> pluck(["a", "b"]) |> run
    assert data == [
      %{"a" => 5, "b" => 6},
      %{"a" => 7, "b" => 8}
    ]
  end

  test "without" do
    {:ok, %Record{data: data}} = [
      %{a: 5, b: 6, c: 3},
      %{a: 7, b: 8}
    ] |> without("a") |> run
    assert data == [
      %{"b" => 6, "c" => 3},
      %{"b" => 8}
    ]
  end

  test "merge" do
    {:ok, %Record{data: data}} = %{a: 4} |> merge(%{b: 5}) |> run
    assert data == %{"a" => 4, "b" => 5}
  end

  test "merge list" do
    {:ok, %Record{data: data}} = args([%{a: 4}, %{b: 5}]) |> merge |> run
    assert data == %{"a" => 4, "b" => 5}
  end

  test "append" do
    {:ok, %Record{data: data}} = [1,2] |> append(3) |> run
    assert data == [1,2,3]
  end

  test "prepend" do
    {:ok, %Record{data: data}} = [1,2] |> prepend(3) |> run
    assert data == [3,1,2]
  end

  test "difference" do
    {:ok, %Record{data: data}} = [1,2] |> difference([2]) |> run
    assert data == [1]
  end

  test "set_insert" do
    {:ok, %Record{data: data}} = [1,2] |> set_insert(2) |> run
    assert data == [1,2]
    {:ok, %Record{data: data}} = [1,2] |> set_insert(3) |> run
    assert data == [1,2,3]
  end

  test "set_intersection" do
    {:ok, %Record{data: data}} = [1,2] |> set_intersection([2,3]) |> run
    assert data == [2]
  end

  test "set_union" do
    {:ok, %Record{data: data}} = [1,2] |> set_union([2,3]) |> run
    assert data == [1,2,3]
  end

  test "set_difference" do
    {:ok, %Record{data: data}} = [1,2,4] |> set_difference([2,3]) |> run
    assert data == [1,4]
  end

  test "get_field" do
    {:ok, %Record{data: data}} = %{a: 5, b: 6} |> get_field("a") |> run
    assert data == 5
  end

  test "has_fields" do
    {:ok, %Record{data: data}} = [
      %{"b" => 6, "c" => 3},
      %{"b" => 8}
    ] |> has_fields(["c"]) |> run
    assert data == [%{"b" => 6, "c" => 3}]
  end

  test "insert_at" do
    {:ok, %Record{data: data}} = [1,2,3] |> insert_at(1, 5) |> run
    assert data == [1,5,2,3]
  end

  test "splice_at" do
    {:ok, %Record{data: data}} = [1,2,3] |> splice_at(1, [5,6]) |> run
    assert data == [1,5,6,2,3]
  end

  test "delete_at" do
    {:ok, %Record{data: data}} = [1,2,3,4] |> delete_at(1) |> run
    assert data == [1,3,4]
    {:ok, %Record{data: data}} = [1,2,3,4] |> delete_at(1,3) |> run
    assert data == [1,4]
  end

  test "change_at" do
    {:ok, %Record{data: data}} = [1,2,3,4] |> change_at(1,7) |> run
    assert data == [1,7,3,4]
  end
  
  test "keys" do
    {:ok, %Record{data: data}} = %{a: 5, b: 6} |> keys |> run
    assert data == ["a", "b"]
  end

  test "values" do
    {:ok, %Record{data: data}} = %{a: 5, b: 6} |> values |> run
    assert data == [5, 6]
  end

  test "literal" do
    {:ok, %Record{data: data}} = %{
      a: 5,
      b: %{
        c: 6
      }
    } |> merge(%{b: literal(%{d: 7})}) |> run
    assert data == %{
      "a" => 5,
      "b" => %{
        "d" => 7
      }
    }
  end

  test "object" do
    {:ok, %Record{data: data}} = object(["a", 1, "b", 2]) |> run
    assert data == %{"a" => 1, "b" => 2}
  end
end
