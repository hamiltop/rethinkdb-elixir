defmodule TransformationTest do
  use ExUnit.Case, async: true

  use RethinkDB.Connection
  import RethinkDB.Query

  alias RethinkDB.Record

  require RethinkDB.Lambda
  import RethinkDB.Lambda

  setup_all do
    start_link()
    :ok
  end

  test "map" do
    {:ok, %Record{data: data}} = map([1,2,3], lambda &(&1 + 1)) |> run
    assert data == [2,3,4]
  end

  test "with_fields" do
    {:ok, %Record{data: data}} = [
        %{a: 5},
        %{a: 6},
        %{a: 7, b: 8}
      ] |> with_fields(["a","b"]) |> run
    assert data == [%{"a" => 7, "b" => 8}]
  end

  test "flat_map" do
    {:ok, %Record{data: data}} = [
      [1,2,3],
      [4,5,6],
      [7,8,9]
    ] |> flat_map(lambda fn (x) ->
      x |> map(&(&1*2))
    end) |> run
    assert data == [2,4,6,8,10,12,14,16,18]
  end

  test "order_by" do
    {:ok, %Record{data: data}} = [
      %{a: 1},
      %{a: 7},
      %{a: 4},
      %{a: 5},
      %{a: 2}
    ] |> order_by("a") |> run
    assert data == [
      %{"a" => 1},
      %{"a" => 2},
      %{"a" => 4},
      %{"a" => 5},
      %{"a" => 7}
    ]
  end

  test "order by descending attr" do
    data = [%{"rank" => 1}, %{"rank" => 2}, %{"rank" => 3}]

    q = data |> order_by(desc("rank"))
    {:ok, %{data: result}} = run(q)

    assert result == Enum.reverse(data)
  end

  test "skip" do
    {:ok, %Record{data: data}} = [1,2,3,4] |> skip(2) |> run
    assert data == [3,4]
  end

  test "limit" do
    {:ok, %Record{data: data}} = [1,2,3,4] |> limit(2) |> run
    assert data == [1,2]
  end

  test "slice" do
    {:ok, %Record{data: data}} = [1,2,3,4] |> slice(1,3) |> run
    assert data == [2,3]
  end

  test "nth" do
    {:ok, %Record{data: data}} = [1,2,3,4] |> nth(2) |> run
    assert data == 3
  end

  test "offsets_of" do
    {:ok, %Record{data: data}} = [1,2,3,1,4,1] |> offsets_of(1) |> run
    assert data == [0,3,5]
  end

  test "is_empty" do
    {:ok, %Record{data: data}} = [] |> is_empty |> run
    assert data == true
    {:ok, %Record{data: data}} = [1,2,3,1,4,1] |> is_empty |> run
    assert data == false
  end

  test "sample" do
    {:ok, %Record{data: data}} = [1,2,3,1,4,1] |> sample(2) |> run
    assert Enum.count(data) == 2
  end
end
