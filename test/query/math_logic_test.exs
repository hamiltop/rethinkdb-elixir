defmodule MathLogicTest do
  use ExUnit.Case
  use TestConnection

  alias Exrethinkdb.Record
  
  setup_all do
    TestConnection.connect
    :ok
  end

  test "add scalars" do
    %Record{data: data} = add(1,2) |> run
    assert data == 3
  end

  test "add list of scalars" do
    %Record{data: data} = add([1,2]) |> run
    assert data == 3
  end

  test "concatenate two strings" do
    %Record{data: data} = add("hello ","world") |> run
    assert data == "hello world"
  end

  test "concatenate list of strings" do
    %Record{data: data} = add(["hello", " ", "world"]) |> run
    assert data == "hello world"
  end

  test "concatenate two arrays" do
    %Record{data: data} = add([1,2,3],[3,4,5]) |> run
    assert data == [1,2,3,3,4,5]
  end
  test "concatenate list of arrays" do
    %Record{data: data} = add([[1,2,3],[3,4,5],[5,6,7]]) |> run
    assert data == [1,2,3,3,4,5,5,6,7]
  end

  test "subtract two numbers" do
    %Record{data: data} = sub(5,2) |> run
    assert data == 3
  end

  test "subtract list of numbers" do
    %Record{data: data} = sub([9,3,1]) |> run
    assert data == 5
  end
end
