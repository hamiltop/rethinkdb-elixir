defmodule AggregationTest do
  use ExUnit.Case, async: true
  use RethinkDB.Connection
  import RethinkDB.Query
  alias RethinkDB.Query

  alias RethinkDB.Record

  require RethinkDB.Lambda
  import RethinkDB.Lambda

  setup_all do
    start_link()
    :ok
  end

  test "group on key name" do
    query = [
        %{a: "hi", b: 1},
        %{a: "hi", b: [1,2,3]},
        %{a: "bye"}
      ]
      |> group("a")
    {:ok, %Record{data: data}} = query |> run
    assert data == %{
      "bye" => [
        %{"a" => "bye"}
      ],
      "hi" => [
        %{"a" => "hi", "b" => 1},
        %{"a" => "hi", "b" => [1,2,3]}
      ]
    }
  end

  test "group on function" do
    query = [
        %{a: "hi", b: 1},
        %{a: "hi", b: [1,2,3]},
        %{a: "bye"},
        %{a: "hello"}
      ]
      |> group(lambda fn (x) ->
        (x["a"] == "hi") || (x["a"] == "hello")
      end)
    {:ok, %Record{data: data}} = query |> run
    assert data == %{
      false: [
        %{"a" => "bye"},
      ],
      true: [
        %{"a" => "hi", "b" => 1},
        %{"a" => "hi", "b" => [1,2,3]},
        %{"a" => "hello"}
      ]
    }
  end

  test "group on multiple keys" do
    query = [
        %{a: "hi", b: 1, c: 2},
        %{a: "hi", b: 1, c: 3},
        %{a: "hi", b: [1,2,3]},
        %{a: "bye"},
        %{a: "hello", b: 1}
      ]
      |> group([lambda(fn (x) ->
        (x["a"] == "hi") || (x["a"] == "hello")
      end), "b"])
    {:ok, %Record{data: data}} = query |> run
    assert data == %{
      [false, nil] => [
        %{"a" => "bye"},
      ],
      [true, 1] => [
        %{"a" => "hi", "b" => 1, "c" => 2},
        %{"a" => "hi", "b" => 1, "c" => 3},
        %{"a" => "hello", "b" => 1},
      ],
      [true, [1,2,3]] => [
        %{"a" => "hi", "b" => [1,2,3]}
      ]
    }
  end

  test "ungroup" do
    query = [
        %{a: "hi", b: 1, c: 2},
        %{a: "hi", b: 1, c: 3},
        %{a: "hi", b: [1,2,3]},
        %{a: "bye"},
        %{a: "hello", b: 1}
      ]
      |> group([lambda(fn (x) ->
        (x["a"] == "hi") || (x["a"] == "hello")
      end), "b"])
      |> ungroup
    {:ok, %Record{data: data}} = query |> run
    assert data == [
      %{
        "group" => [false, nil],
        "reduction" => [
          %{"a" => "bye"},
        ]
      },
      %{
        "group" => [true, [1,2,3]],
        "reduction" => [
          %{"a" => "hi", "b" => [1,2,3]}
        ]
      },
      %{
        "group" => [true, 1],
        "reduction" => [
          %{"a" => "hi", "b" => 1, "c" => 2},
          %{"a" => "hi", "b" => 1, "c" => 3},
          %{"a" => "hello", "b" => 1},
        ]
      }
    ]
  end

  test "reduce" do
    query = [1,2,3,4] |> reduce(lambda fn(el, acc) ->
      el + acc
    end)
    {:ok, %Record{data: data}} = run query
    assert data == 10
  end

  test "count" do
    query = [1,2,3,4] |> count
    {:ok, %Record{data: data}} = run query
    assert data == 4
  end

  test "count with value" do
    query = [1,2,2,3,4] |> count(2)
    {:ok, %Record{data: data}} = run query
    assert data == 2
  end

  test "count with predicate" do
    query = [1,2,2,3,4] |> count(lambda fn(x) ->
      rem(x, 2) == 0
    end)
    {:ok, %Record{data: data}} = run query
    assert data == 3
  end

  test "sum" do
    query = [1,2,3,4] |> sum
    {:ok, %Record{data: data}} = run query
    assert data == 10
  end

  test "sum with field" do
    query = [%{a: 1},%{a: 2},%{b: 3},%{b: 4}] |> sum("a")
    {:ok, %Record{data: data}} = run query
    assert data == 3
  end

  test "sum with function" do
    query = [1,2,3,4] |> sum(lambda fn (x) ->
      if x == 1 do
        nil
      else
        x * 2
      end
    end)
    {:ok, %Record{data: data}} = run query
    assert data == 18
  end

  test "avg" do
    query = [1,2,3,4] |> avg
    {:ok, %Record{data: data}} = run query
    assert data == 2.5
  end

  test "avg with field" do
    query = [%{a: 1},%{a: 2},%{b: 3},%{b: 4}] |> avg("a")
    {:ok, %Record{data: data}} = run query
    assert data == 1.5
  end

  test "avg with function" do
    query = [1,2,3,4] |> avg(lambda fn (x) ->
      if x == 1 do
        nil
      else
        x * 2
      end
    end)
    {:ok, %Record{data: data}} = run query
    assert data == 6
  end

  test "min" do
    query = [1,2,3,4] |> Query.min
    {:ok, %Record{data: data}} = run query
    assert data == 1
  end

  test "min with field" do
    query = [%{a: 1},%{a: 2},%{b: 3},%{b: 4}] |> Query.min("b")
    {:ok, %Record{data: data}} = run query
    assert data == %{"b" => 3}
  end

  test "min with subquery field" do
    query = [%{a: 1},%{a: 2},%{b: 3},%{b: 4}] |> Query.min(Query.downcase("B"))
    {:ok, %Record{data: data}} = run query
    assert data == %{"b" => 3}
  end

  test "min with function" do
    query = [1,2,3,4] |> Query.min(lambda fn (x) ->
      if x == 1 do
        100 # Note, there's a bug in rethinkdb (https://github.com/rethinkdb/rethinkdb/issues/4213)
            # which means we can't return null here
      else
        x * 2
      end
    end)
    {:ok, %Record{data: data}} = run query
    assert data == 2  
  end

  test "max" do
    query = [1,2,3,4] |> Query.max
    {:ok, %Record{data: data}} = run query
    assert data == 4
  end

  test "max with field" do
    query = [%{a: 1},%{a: 2},%{b: 3},%{b: 4}] |> Query.max("b")
    {:ok, %Record{data: data}} = run query
    assert data == %{"b" => 4}
  end

  test "max with subquery field" do
    query = [%{a: 1},%{a: 2},%{b: 3},%{b: 4}] |> Query.max(Query.downcase("B"))
    {:ok, %Record{data: data}} = run query
    assert data == %{"b" => 4}
  end

  test "max with function" do
    query = [1,2,3,4] |> Query.max(lambda fn (x) ->
      if x == 4 do
        nil
      else
        x * 2
      end
    end)
    {:ok, %Record{data: data}} = run query
    assert data == 3
  end

  test "distinct" do
    query = [1,2,3,3,4,4,5] |> distinct
    {:ok, %Record{data: data}} = run query
    assert data == [1,2,3,4,5]
  end

  test "distinct with opts" do
    query = [1,2,3,4] |> distinct(index: "stuff")
    assert %RethinkDB.Q{query: [_, _, %{index: "stuff"}]} = query
  end

  test "contains" do
    query = [1,2,3,4] |> contains(4)
    {:ok, %Record{data: data}} = run query
    assert data == true
  end

  test "contains multiple values" do
    query = [1,2,3,4] |> contains([4, 3])
    {:ok, %Record{data: data}} = run query
    assert data == true
  end

  test "contains with function" do
    query = [1,2,3,4] |> contains(lambda &(&1 == 3))
    {:ok, %Record{data: data}} = run query
    assert data == true
  end

  test "contains with multiple function" do
    query = [1,2,3,4] |> contains([lambda(&(&1 == 3)), lambda(&(&1 == 5))])
    {:ok, %Record{data: data}} = run query
    assert data == false
  end

  test "contains with multiple (mixed)" do
    query = [1,2,3,4] |> contains([lambda(&(&1 == 3)), 2])
    {:ok, %Record{data: data}} = run query
    assert data == true
  end
end
