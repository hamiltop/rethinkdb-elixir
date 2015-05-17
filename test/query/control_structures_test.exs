defmodule ControlStructuresTest do
  use ExUnit.Case
  use TestConnection

  alias RethinkDB.Record
  alias RethinkDB.Collection
  alias RethinkDB.Response

  setup_all do
    connect
    :ok
  end

  @db_name "query_test_db_1"
  @table_name "query_test_table_1"
  setup do
    q = db_drop(@db_name)
    run(q)
    q = db_create(@db_name)
    run(q)
    q = db(@db_name) |> table_create(@table_name)
    run(q)
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

  test "branch" do
    q = branch(true, 1, 2)
    %Record{data: data} = run q
    assert data == 1 
    q = branch(false, 1, 2)
    %Record{data: data} = run q
    assert data == 2 
  end

  test "for_each" do
    table_query = db(@db_name) |> table(@table_name)
    q = [1,2,3] |> for_each(fn(x) ->
      table_query |> insert(%{a: x})
    end)
    run q
    %Collection{data: data} = run table_query
    assert Enum.count(data) == 3
  end

  test "error" do
    q = do_r(fn -> error("hello") end)
    %Response{data: data} = run q
    assert data["r"] == ["hello"]
  end

  test "default" do
    q = 1 |> default "test"
    %Record{data: data} = run q
    assert data == 1
    q = nil |> default "test"
    %Record{data: data} = run q
    assert data == "test"
  end

  test "js" do
    q = js "[40,100,1,5,25,10].sort()"
    %Record{data: data} = run q
    assert data == [1,10,100,25,40,5] # couldn't help myself...
  end

  test "coerce_to" do
    q = "91" |> coerce_to "number"  
    %Record{data: data} = run q
    assert data == 91
  end

  test "type_of" do
    q = "91" |> type_of
    %Record{data: data} = run q
    assert data == "STRING"
    q = 91 |> type_of
    %Record{data: data} = run q
    assert data == "NUMBER"
    q = [91] |> type_of
    %Record{data: data} = run q
    assert data == "ARRAY"
  end

  test "info" do
    q = [91] |> info
    %Record{data: data} = run q
    assert data == %{"type" => "ARRAY", "value" => "[91]"}
  end

  test "json" do
    q = "{\"a\": 5, \"b\": 6}" |> json
    %Record{data: data} = run q
    assert data == %{"a" => 5, "b" => 6}
  end

  test "http" do
    q = "http://httpbin.org/get" |> http
    %Record{data: data} = run q
    assert data == %{"args" => %{},
      "headers" => %{"Accept" => "*/*", "Accept-Encoding" => "deflate;q=1, gzip;q=0.5",
        "Host" => "httpbin.org", "User-Agent" => "RethinkDB/2.0.1"},
      "origin" => "76.103.35.5", "url" => "http://httpbin.org/get"}
  end

  test "uuid" do
    q = uuid  
    %Record{data: data} = run q
    assert String.length(String.replace(data, "-", ""))  == 32
  end
end
