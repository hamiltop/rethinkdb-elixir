defmodule StringManipulationTest do
  use ExUnit.Case, async: true
  import RethinkDB.Connection
  import RethinkDB.Query

  alias RethinkDB.Record

  setup_all do
    {:ok, pid} = RethinkDB.Connection.start_link()
    {:ok, %{conn: pid}}
  end

  test "match a string", context do
    {:ok, %Record{data: data}} = "hello world" |> match("hello") |> run(context.conn)
    assert data == %{"end" => 5, "groups" => [], "start" => 0, "str" => "hello"}
  end

  test "match a regex", context do
    {:ok, %Record{data: data}} = "hello world" |> match(~r(hello)) |> run(context.conn)
    assert data == %{"end" => 5, "groups" => [], "start" => 0, "str" => "hello"}
  end

  test "split a string", context do
    {:ok, %Record{data: data}} = "abracadabra" |> split |> run(context.conn)
    assert data == ["abracadabra"]
    {:ok, %Record{data: data}} = "abra-cadabra" |> split("-") |> run(context.conn)
    assert data == ["abra", "cadabra"]
    {:ok, %Record{data: data}} = "a-bra-ca-da-bra" |> split("-", 2) |> run(context.conn)
    assert data == ["a", "bra", "ca-da-bra"]
  end

  test "upcase", context do
    {:ok, %Record{data: data}} = "hi" |> upcase |> run(context.conn)
    assert data == "HI"
  end
  test "downcase", context do
    {:ok, %Record{data: data}} = "Hi" |> downcase |> run(context.conn)
    assert data == "hi"
  end
end
