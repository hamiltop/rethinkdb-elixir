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

  @doc """
  Loop over a sequence, evaluating the given write query for each element.
  """
  @spec for_each(Q.reql_array, Q.reql_func1) :: Q.t
  operate_on_two_args(:for_each, 68)

  @doc """
  Throw a runtime error.
  """
  @spec error(Q.reql_string) :: Q.t
  operate_on_single_arg(:error, 12)

  @doc """
  Handle non-existence errors. Tries to evaluate and return its first argument. 
  If an error related to the absence of a value is thrown in the process, or if 
  its first argument returns nil, returns its second argument. (Alternatively, 
  the second argument may be a function which will be called with either the text 
  of the non-existence error or nil.)
  """
  @spec default(Q.t, Q.t) :: Q.t
  operate_on_two_args(:default, 92)

  @doc """
  Create a javascript expression.

  `timeout` is the number of seconds before `js` times out. The default value 
  is 5 seconds.
  """
  @spec js(Q.reql_string, Q.reql_number) :: Q.t
  operate_on_single_arg(:js, 11)
  def js(javascript, number), do: %Q{query: [11, [wrap(javascript)], %{timeout: number}]}

  @doc """
  Convert a value of one type into another.

  * a sequence, selection or object can be coerced to an array
  * an array of key-value pairs can be coerced to an object
  * a string can be coerced to a number
  * any datum (single value) can be coerced to a string
  * a binary object can be coerced to a string and vice-versa
  """
  @spec coerce_to(Q.reql_datum, Q.reql_string) :: Q.t
  operate_on_two_args(:coerce_to, 51)

  @doc """
  Gets the type of a value.
  """
  @spec type_of(Q.reql_datum) :: Q.t
  operate_on_single_arg(:type_of, 52)

  @doc """
  Get information about a ReQL value.
  """
  @spec info(Q.t) :: Q.t
  operate_on_single_arg(:info, 79)

  @doc """
  Parse a JSON string on the server.
  """
  @spec json(Q.reql_string) :: Q.t
  operate_on_single_arg(:json, 98)

  @doc """
  Retrieve data from the specified URL over HTTP. The return type depends on 
  the result_format option, which checks the Content-Type of the response by 
  default.
  """
  @spec http(Q.reql_string, Q.reql_obj) :: Q.t
  def http(url, opts \\ %{}), do: %Q{query: [153, [url], opts]}

  @doc """
  Return a UUID (universally unique identifier), a string that can be used as a unique ID.
  """
  @spec uuid() :: Q.t
  operate_on_zero_args(:uuid, 169)
end
