defmodule AggregationTest do
  use ExUnit.Case
  use TestConnection

  alias RethinkDB.Record

  setup_all do
    connect
    :ok
  end

  test "args" do
    q = [%{a: 5, b: 6}, %{a: 4, c: 7}] |> pluck(args(["a","c"]))
    %Record{data: data} = run q
    assert data == [%{"a" => 5}, %{"a" => 4, "c" => 7}]
  end

  test "binary" do
    d = << 1,2,3,4,5,6 >>
    q = binary d
    %Record{data: data} = run q
    assert data == %RethinkDB.Pseudotypes.Binary{data: d}
    q = binary data
    %Record{data: result} = run q
    assert data == result
  end

  test "do_r" do
    q = do_r fn -> 5 end
    %Record{data: data} = run q
    assert data == 5
    q = [1,2,3] |> do_r fn x -> x end
    %Record{data: data} = run q
    assert data == [1,2,3]
  end
end
