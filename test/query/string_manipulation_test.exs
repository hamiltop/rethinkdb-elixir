defmodule StringManipulationTest do
  use ExUnit.Case
  use Exrethinkdb

  alias Exrethinkdb.Record
  
  setup_all do
    Exrethinkdb.connect
    :ok
  end

  test "match a string" do
    %Record{data: data} = "hello world" |> match("hello") |> run
    assert data == %{"end" => 5, "groups" => [], "start" => 0, "str" => "hello"}
  end

  test "match a regex" do
    %Record{data: data} = "hello world" |> match(~r(hello)) |> run
    assert data == %{"end" => 5, "groups" => [], "start" => 0, "str" => "hello"}
  end

  test "split a string" do
    %Record{data: data} = "abracadabra" |> split |> run
    assert data == ["abracadabra"]
    %Record{data: data} = "abra-cadabra" |> split("-") |> run
    assert data == ["abra", "cadabra"]
    %Record{data: data} = "a-bra-ca-da-bra" |> split("-", 2) |> run
    assert data == ["a", "bra", "ca-da-bra"]
  end

  test "upcase" do
    %Record{data: data} = "hi" |> upcase |> run
    assert data == "HI"
  end
  test "downcase" do
    %Record{data: data} = "Hi" |> downcase |> run
    assert data == "hi"
  end
end
