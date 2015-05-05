defmodule Exrethinkdb.Query.MathLogic do
  alias Exrethinkdb.Query, as: Q
  @moduledoc """
  ReQL methods for math and logic operations.

  All examples assume that `use Exrethinkdb` has been called.
  """

  require Exrethinkdb.Query.Macros
  import Exrethinkdb.Query.Macros

  @doc """
  Add two values together. If the two values are numbers, then add them. If they are strings then
  concat them. If they are arrays concat them.

    iex> add(1, 2) |> run conn
    %Exrethinkdb.Record{data: 3}

    iex> add("hello", " world") |> run conn
    %Exrethinkdb.Record{data: "hello world"}

    iex> add([1,2], [3,4]) |> run conn
    %Exrethinkdb.Record{data: [1,2,3,4]}

  """
  @spec add((Q.reql_number | Q.reql_string), (Q.reql_number | Q.reql_string)) :: Q.t
  operate_on_two_args(:add, 24)

  @doc """
  Add multiple values together. Numbers are summed, Strings are concatenated, Arrays are concatenated.

    iex> add([1, 2]) |> run conn
    %Exrethinkdb.Record{data: 3}

    iex> add(["hello", " world"]) |> run
    %Exrethinkdb.Record{data: "hello world"}
  """
  @spec add([(Q.reql_number | Q.reql_string | Q.repl_array)]) :: Q.t
  operate_on_list(:add, 24)

  @doc """
  Subtract values. The second number is subtracted from the first.

    iex> sub(1, 2) |> run conn
    %Exrethinkdb.Record{data: -1}

  """
  @spec sub(Q.reql_number, Q.reql_number) :: Q.t
  operate_on_two_args(:sub, 25)

  @doc """
  Subtract values. Subtracts numbers from left to right.

    iex> sub([9, 1, 2]) |> run conn
    %Exrethinkdb.Record{data: 6}

  """
  @spec sub([Q.reql_number]) :: Q.t
  operate_on_list(:sub, 25)
end
