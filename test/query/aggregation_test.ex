defmodule AggregationTest do
  use ExUnit.Case
  use TestConnection

  alias Exrethinkdb.Record

  require Exrethinkdb.Lambda
  import Exrethinkdb.Lambda

  setup_all do
    TestConnection.connect
    :ok
  end

  test "group on key name" do
    query = [
        %{a: "hi", b: 1},
        %{a: "hi", b: [1,2,3]},
        %{a: "bye"}
      ]
      |> group("a")
    a = %Record{data: data} = query |> run
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
    a = %Record{data: data} = query |> run
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
    a = %Record{data: data} = query |> run
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
end
