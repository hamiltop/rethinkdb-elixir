defmodule RethinkDB.Query.MathLogic do
  alias RethinkDB.Query, as: Q
  @moduledoc """
  ReQL methods for math and logic operations.

  All examples assume that `use RethinkDB` has been called.
  """

  require RethinkDB.Query.Macros
  import RethinkDB.Query.Macros

  @doc """
  Sum two numbers, concatenate two strings, or concatenate 2 arrays.

      iex> add(1, 2) |> run conn
      %RethinkDB.Record{data: 3}

      iex> add("hello", " world") |> run conn
      %RethinkDB.Record{data: "hello world"}

      iex> add([1,2], [3,4]) |> run conn
      %RethinkDB.Record{data: [1,2,3,4]}

  """
  @spec add((Q.reql_number | Q.reql_string), (Q.reql_number | Q.reql_string)) :: Q.t
  operate_on_two_args(:add, 24)

  @doc """
  Add multiple values.

      iex> add([1, 2]) |> run conn
      %RethinkDB.Record{data: 3}

      iex> add(["hello", " world"]) |> run
      %RethinkDB.Record{data: "hello world"}

  """
  @spec add([(Q.reql_number | Q.reql_string | Q.reql_array)]) :: Q.t
  operate_on_list(:add, 24)

  @doc """
  Subtract two numbers.

      iex> sub(1, 2) |> run conn
      %RethinkDB.Record{data: -1}

  """
  @spec sub(Q.reql_number, Q.reql_number) :: Q.t
  operate_on_two_args(:sub, 25)

  @doc """
  Subtract multiple values. Left associative.

      iex> sub([9, 1, 2]) |> run conn
      %RethinkDB.Record{data: 6}

  """
  @spec sub([Q.reql_number]) :: Q.t
  operate_on_list(:sub, 25)

  @doc """
  Multiply two numbers, or make a periodic array.

      iex> mul(2,3) |> run conn
      %RethinkDB.Record{data: 6}

      iex> mul([1,2], 2) |> run conn
      %RethinkDB.Record{data: [1,2,1,2]}

  """
  @spec mul((Q.reql_number | Q.reql_array), (Q.reql_number | Q.reql_array)) :: Q.t
  operate_on_two_args(:mul, 26)
  @doc """
  Multiply multiple values.

      iex> mul([2,3,4]) |> run conn
      %RethinkDB.Record{data: 24}

  """
  @spec mul([(Q.reql_number | Q.reql_array)]) :: Q.t
  operate_on_list(:mul, 26)

  @doc """
  Divide two numbers.

      iex> divide(12, 4) |> run conn
      %RethinkDB.Record{data: 3}

  """
  @spec divide(Q.reql_number, Q.reql_number) :: Q.t
  operate_on_two_args(:divide, 27)
  @doc """
  Divide a list of numbers. Left associative.

      iex> divide([12, 2, 3]) |> run conn
      %RethinkDB.Record{data: 2}

  """
  @spec divide([Q.reql_number]) :: Q.t
  operate_on_list(:divide, 27)

  @doc """
  Find the remainder when dividing two numbers.

      iex> mod(23, 4) |> run conn
      %RethinkDB.Record{data: 3}

  """
  @spec mod(Q.reql_number, Q.reql_number) :: Q.t
  operate_on_two_args(:mod, 28)

  @doc """ 
  Compute the logical “and” of two values.

      iex> and(true, true) |> run conn
      %RethinkDB.Record{data: true}

      iex> and(false, true) |> run conn
      %RethinkDB.Record{data: false}
  """
  @spec and_r(Q.reql_bool, Q.reql_bool) :: Q.t
  operate_on_two_args(:and_r, 67)
  @doc """ 
  Compute the logical “and” of all values in a list.

      iex> and_r([true, true, true]) |> run conn
      %RethinkDB.Record{data: true}

      iex> and_r([false, true, true]) |> run conn
      %RethinkDB.Record{data: false}
  """
  @spec and_r([Q.reql_bool]) :: Q.t
  operate_on_list(:and_r, 67)

  @doc """
  Compute the logical “or” of two values.

      iex> or_r(true, false) |> run conn
      %RethinkDB.Record{data: true}

      iex> or_r(false, false) |> run conn
      %RethinkDB.Record{data: false}

  """
  @spec or_r(Q.reql_bool, Q.reql_bool) :: Q.t
  operate_on_two_args(:or_r, 66)
  @doc """
  Compute the logical “or” of all values in a list.

      iex> or_r([true, true, true]) |> run conn
      %RethinkDB.Record{data: true}

      iex> or_r([false, true, true]) |> run conn
      %RethinkDB.Record{data: false}

  """
  @spec or_r([Q.reql_bool]) :: Q.t
  operate_on_list(:or_r, 66)

  @doc """
  Test if two values are equal.

      iex> eq(1,1) |> run conn
      %RethinkDB.Record{data: true}

      iex> eq(1, 2) |> run conn
      %RethinkDB.Record{data: false}
  """
  @spec eq(Q.reql_datum, Q.reql_datum) :: Q.t
  operate_on_two_args(:eq, 17)
  @doc """
  Test if all values in a list are equal.

      iex> eq([2, 2, 2]) |> run conn
      %RethinkDB.Record{data: true}

      iex> eq([2, 1, 2]) |> run conn
      %RethinkDB.Record{data: false}
  """
  @spec eq([Q.reql_datum]) :: Q.t
  operate_on_list(:eq, 17)
    
  @doc """
  Test if two values are not equal.

      iex> ne(1,1) |> run conn
      %RethinkDB.Record{data: false}

      iex> ne(1, 2) |> run conn
      %RethinkDB.Record{data: true}
  """
  @spec ne(Q.reql_datum, Q.reql_datum) :: Q.t
  operate_on_two_args(:ne, 18)
  @doc """
  Test if all values in a list are not equal.

      iex> ne([2, 2, 2]) |> run conn
      %RethinkDB.Record{data: false}

      iex> ne([2, 1, 2]) |> run conn
      %RethinkDB.Record{data: true}
  """
  @spec ne([Q.reql_datum]) :: Q.t
  operate_on_list(:ne, 18)

  @doc """
  Test if one value is less than the other.

      iex> lt(2,1) |> run conn
      %RethinkDB.Record{data: false}

      iex> lt(1, 2) |> run conn
      %RethinkDB.Record{data: true}
  """
  @spec lt(Q.reql_datum, Q.reql_datum) :: Q.t
  operate_on_two_args(:lt, 19)
  @doc """
  Test if all values in a list are less than the next. Left associative.

      iex> lt([1, 4, 2]) |> run conn
      %RethinkDB.Record{data: false}

      iex> lt([1, 4, 5]) |> run conn
      %RethinkDB.Record{data: true}
  """
  @spec lt([Q.reql_datum]) :: Q.t
  operate_on_list(:lt, 19)

  @doc """
  Test if one value is less than or equal to the other.

      iex> le(1,1) |> run conn
      %RethinkDB.Record{data: true}

      iex> le(1, 2) |> run conn
      %RethinkDB.Record{data: true}
  """
  @spec le(Q.reql_datum, Q.reql_datum) :: Q.t
  operate_on_two_args(:le, 20)
  @doc """
  Test if all values in a list are less than or equal to the next. Left associative.

      iex> le([1, 4, 2]) |> run conn
      %RethinkDB.Record{data: false}

      iex> le([1, 4, 4]) |> run conn
      %RethinkDB.Record{data: true}
  """
  @spec le([Q.reql_datum]) :: Q.t
  operate_on_list(:le, 20)

  @doc """
  Test if one value is greater than the other.

      iex> gt(1,2) |> run conn
      %RethinkDB.Record{data: false}

      iex> gt(2,1) |> run conn
      %RethinkDB.Record{data: true}
  """
  @spec gt(Q.reql_datum, Q.reql_datum) :: Q.t
  operate_on_two_args(:gt, 21)
  @doc """
  Test if all values in a list are greater than the next. Left associative.

      iex> gt([1, 4, 2]) |> run conn
      %RethinkDB.Record{data: false}

      iex> gt([10, 4, 2]) |> run conn
      %RethinkDB.Record{data: true}
  """
  @spec gt([Q.reql_datum]) :: Q.t
  operate_on_list(:gt, 21)

  @doc """
  Test if one value is greater than or equal to the other.

      iex> ge(1,1) |> run conn
      %RethinkDB.Record{data: true}

      iex> ge(2, 1) |> run conn
      %RethinkDB.Record{data: true}
  """
  @spec ge(Q.reql_datum, Q.reql_datum) :: Q.t
  operate_on_two_args(:ge, 22)
  @doc """
  Test if all values in a list are greater than or equal to the next. Left associative.

      iex> le([1, 4, 2]) |> run conn
      %RethinkDB.Record{data: false}

      iex> le([10, 4, 4]) |> run conn
      %RethinkDB.Record{data: true}
  """
  @spec ge([Q.reql_datum]) :: Q.t
  operate_on_list(:ge, 22)

  @doc """
  Compute the logical inverse (not) of an expression.

      iex> not(true) |> run conn
      %RethinkDB.Record{data: false}

  """
  @spec not_r(Q.reql_bool) :: Q.t
  operate_on_single_arg(:not_r, 23)

  @doc """
  Generate a random float between 0 and 1.

      iex> random |> run conn
      %RethinkDB.Record{data: 0.43}

  """
  @spec random :: Q.t
  def random, do: %Q{query: [151, []]}
  @doc """
  Generate a random value in the range [0,upper). If upper is an integer then the
  random value will be an interger. If upper is a float it will be a float.

      iex> random(5) |> run conn
      %RethinkDB.Record{data: 3}

      iex> random(5.0) |> run conn
      %RethinkDB.Record{data: 3.7}

  """
  @spec random(Q.reql_number) :: Q.t
  def random(upper) when is_integer(upper), do: %Q{query: [151, [upper]]}
  def random(upper) when is_float(upper), do: %Q{query: [151, [upper], %{float: true}]}
  @doc """
  Generate a random value in the range [lower,upper). If either arg is an integer then the
  random value will be an interger. If one of them is a float it will be a float.

      iex> random(5, 10) |> run conn
      %RethinkDB.Record{data: 8}

      iex> random(5.0, 15.0,) |> run conn
      %RethinkDB.Record{data: 8.34}

  """
  @spec random(Q.reql_number, Q.reql_number) :: Q.t
  def random(lower, upper) when is_integer(lower) and is_integer(upper) do
    %Q{query: [151, [lower, upper]]}
  end
  def random(lower, upper) when is_float(lower) or is_float(upper) do
    %Q{query: [151, [lower, upper], %{float: true}]}
  end
end
