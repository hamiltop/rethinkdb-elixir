defmodule MathLogicTest do
  use ExUnit.Case, async: false
  use RethinkDB.Connection
  import RethinkDB.Query

  alias RethinkDB.Record

  setup_all do
    start_link()
    :ok
  end

  test "add scalars" do
    {:ok, %Record{data: data}} = add(1, 2) |> run
    assert data == 3
  end

  test "add list of scalars" do
    {:ok, %Record{data: data}} = add([1, 2]) |> run
    assert data == 3
  end

  test "concatenate two strings" do
    {:ok, %Record{data: data}} = add("hello ", "world") |> run
    assert data == "hello world"
  end

  test "concatenate list of strings" do
    {:ok, %Record{data: data}} = add(["hello", " ", "world"]) |> run
    assert data == "hello world"
  end

  test "concatenate two arrays" do
    {:ok, %Record{data: data}} = add([1, 2, 3], [3, 4, 5]) |> run
    assert data == [1, 2, 3, 3, 4, 5]
  end

  test "concatenate list of arrays" do
    {:ok, %Record{data: data}} = add([[1, 2, 3], [3, 4, 5], [5, 6, 7]]) |> run
    assert data == [1, 2, 3, 3, 4, 5, 5, 6, 7]
  end

  test "subtract two numbers" do
    {:ok, %Record{data: data}} = sub(5, 2) |> run
    assert data == 3
  end

  test "subtract list of numbers" do
    {:ok, %Record{data: data}} = sub([9, 3, 1]) |> run
    assert data == 5
  end

  test "multiply two numbers" do
    {:ok, %Record{data: data}} = mul(5, 2) |> run
    assert data == 10
  end

  test "multiply list of numbers" do
    {:ok, %Record{data: data}} = mul([1, 2, 3, 4, 5]) |> run
    assert data == 120
  end

  test "create periodic array" do
    {:ok, %Record{data: data}} = mul(3, [1, 2]) |> run
    assert data == [1, 2, 1, 2, 1, 2]
  end

  test "divide two numbers" do
    {:ok, %Record{data: data}} = divide(6, 3) |> run
    assert data == 2
  end

  test "divide list of numbers" do
    {:ok, %Record{data: data}} = divide([12, 3, 2]) |> run
    assert data == 2
  end

  test "find remainder when dividing two numbers" do
    {:ok, %Record{data: data}} = mod(23, 4) |> run
    assert data == 3
  end

  test "logical and of two values" do
    {:ok, %Record{data: data}} = and_r(true, true) |> run
    assert data == true
  end

  test "logical and of list" do
    {:ok, %Record{data: data}} = and_r([true, true, false]) |> run
    assert data == false
  end

  test "logical or of two values" do
    {:ok, %Record{data: data}} = or_r(true, false) |> run
    assert data == true
  end

  test "logical or of list" do
    {:ok, %Record{data: data}} = or_r([false, false, false]) |> run
    assert data == false
  end

  test "two numbers are equal" do
    {:ok, %Record{data: data}} = eq(1, 1) |> run
    assert data == true
    {:ok, %Record{data: data}} = eq(2, 1) |> run
    assert data == false
  end

  test "values in a list are equal" do
    {:ok, %Record{data: data}} = eq([1, 1, 1]) |> run
    assert data == true
    {:ok, %Record{data: data}} = eq([1, 2, 1]) |> run
    assert data == false
  end

  test "two numbers are not equal" do
    {:ok, %Record{data: data}} = ne(1, 1) |> run
    assert data == false
    {:ok, %Record{data: data}} = ne(2, 1) |> run
    assert data == true
  end

  test "values in a list are not equal" do
    {:ok, %Record{data: data}} = ne([1, 1, 1]) |> run
    assert data == false
    {:ok, %Record{data: data}} = ne([1, 2, 1]) |> run
    assert data == true
  end

  test "a number is less than the other" do
    {:ok, %Record{data: data}} = lt(2, 1) |> run
    assert data == false
    {:ok, %Record{data: data}} = lt(1, 2) |> run
    assert data == true
  end

  test "values in a list less than the next" do
    {:ok, %Record{data: data}} = lt([1, 4, 2]) |> run
    assert data == false
    {:ok, %Record{data: data}} = lt([1, 4, 5]) |> run
    assert data == true
  end

  test "a number is less than or equal to the other" do
    {:ok, %Record{data: data}} = le(1, 1) |> run
    assert data == true
    {:ok, %Record{data: data}} = le(1, 2) |> run
    assert data == true
  end

  test "values in a list less than or equal to the next" do
    {:ok, %Record{data: data}} = le([1, 4, 2]) |> run
    assert data == false
    {:ok, %Record{data: data}} = le([1, 4, 4]) |> run
    assert data == true
  end

  test "a number is greater than the other" do
    {:ok, %Record{data: data}} = gt(1, 1) |> run
    assert data == false
    {:ok, %Record{data: data}} = gt(2, 1) |> run
    assert data == true
  end

  test "values in a list greater than the next" do
    {:ok, %Record{data: data}} = gt([1, 4, 2]) |> run
    assert data == false
    {:ok, %Record{data: data}} = gt([10, 4, 2]) |> run
    assert data == true
  end

  test "a number is greater than or equal to the other" do
    {:ok, %Record{data: data}} = ge(1, 1) |> run
    assert data == true
    {:ok, %Record{data: data}} = ge(2, 1) |> run
    assert data == true
  end

  test "values in a list greater than or equal to the next" do
    {:ok, %Record{data: data}} = ge([1, 4, 2]) |> run
    assert data == false
    {:ok, %Record{data: data}} = ge([10, 4, 4]) |> run
    assert data == true
  end

  test "not operator" do
    {:ok, %Record{data: data}} = not_r(true) |> run
    assert data == false
  end

  test "random operator" do
    {:ok, %Record{data: data}} = random() |> run
    assert data >= 0.0 && data <= 1.0
    {:ok, %Record{data: data}} = random(100) |> run
    assert is_integer(data) && data >= 0 && data <= 100
    {:ok, %Record{data: data}} = random(100.0) |> run
    assert is_float(data) && data >= 0.0 && data <= 100.0
    {:ok, %Record{data: data}} = random(50, 100) |> run
    assert is_integer(data) && data >= 50 && data <= 100
    {:ok, %Record{data: data}} = random(50, 100.0) |> run
    assert is_float(data) && data >= 50.0 && data <= 100.0
  end

  test "round" do
    {:ok, %Record{data: data}} = round_r(0.3) |> run
    assert data == 0
    {:ok, %Record{data: data}} = round_r(0.6) |> run
    assert data == 1
  end

  test "ceil" do
    {:ok, %Record{data: data}} = ceil(0.3) |> run
    assert data == 1
    {:ok, %Record{data: data}} = ceil(0.6) |> run
    assert data == 1
  end

  test "floor" do
    {:ok, %Record{data: data}} = floor(0.3) |> run
    assert data == 0
    {:ok, %Record{data: data}} = floor(0.6) |> run
    assert data == 0
  end
end
