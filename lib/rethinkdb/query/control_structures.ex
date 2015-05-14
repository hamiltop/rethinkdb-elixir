defmodule RethinkDB.Query.ControlStructures do
  alias RethinkDB.Query, as: Q
  @moduledoc """
  ReQL method for Control Structure operations.

  All examples assume that `use RethinkDB` has been called.
  """

  require RethinkDB.Query.Macros
  import RethinkDB.Query.Macros

  @doc """
  `args` is a special term that’s used to splice an array of arguments into 
  another term. This is useful when you want to call a variadic term such as 
  `get_all` with a set of arguments produced at runtime.

  This is analogous to Elixir's `apply`.
  """
  @spec args(Q.reql_array) :: Q.t
  operate_on_single_arg(:args, 154)

  @doc """
  Encapsulate binary data within a query.

  Only a limited subset of ReQL commands may be chained after binary:

  * coerce_to can coerce binary objects to string types
  * count will return the number of bytes in the object
  * slice will treat bytes like array indexes (i.e., slice(10,20) will return bytes 
  * 10–19)
  * type_of returns PTYPE<BINARY>
  * info will return information on a binary object.
  """
  @spec binary(Q.reql_binary) :: Q.t
  def binary(%RethinkDB.Pseudotypes.Binary{data: data}), do: binary(data)
  operate_on_single_arg(:binary, 155)

  @doc """
  Call an anonymous function using return values from other ReQL commands or 
  queries as arguments.

  The last argument to do (or, in some forms, the only argument) is an expression 
  or an anonymous function which receives values from either the previous 
  arguments or from prefixed commands chained before do. The do command is 
  essentially a single-element map, letting you map a function over just one 
  document. This allows you to bind a query result to a local variable within the 
  scope of do, letting you compute the result just once and reuse it in a complex 
  expression or in a series of ReQL commands.

  Arguments passed to the do function must be basic data types, and cannot be 
  streams or selections. (Read about ReQL data types.) While the arguments will 
  all be evaluated before the function is executed, they may be evaluated in any 
  order, so their values should not be dependent on one another. The type of do’s 
  result is the type of the value returned from the function or last expression.
  """
  @spec do_r(Q.reql_datum | Q.reql_func0, Q.reql_func1) :: Q.t
  operate_on_single_arg(:do_r, 64)
  def do_r(data, f) when is_function(f), do: %Q{query: [64, [wrap(f), wrap(data)]]}

  @doc """
  If the `test` expression returns False or None, the false_branch will be 
  evaluated. Otherwise, the true_branch will be evaluated.

  The branch command is effectively an if renamed due to language constraints.
  """
  @spec branch(Q.reql_datum, Q.reql_datum, Q.reql_datum) :: Q.t
  def branch(test, true_branch, false_branch) do
    %Q{query: [65, [wrap(test), wrap(true_branch), wrap(false_branch)]]}
  end
end
