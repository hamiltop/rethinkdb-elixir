defmodule Exrethinkdb.Query.Aggregation do
  alias Exrethinkdb.Query, as: Q
  @moduledoc """
  ReQL methods for aggregation operations.

  All examples assume that `use Exrethinkdb` has been called.
  """

  require Exrethinkdb.Query.Macros
  import Exrethinkdb.Query.Macros

  @doc """
  Takes a stream and partitions it into multiple groups based on the fields or 
  functions provided.

  With the multi flag single documents can be assigned to multiple groups, 
  similar to the behavior of multi-indexes. When multi is True and the grouping 
  value is an array, documents will be placed in each group that corresponds to 
  the elements of the array. If the array is empty the row will be ignored.
  """
  @spec group(Q.reql_array, Q.reql_func1 | Q.reql_string | [Q.reql_func1 | Q.reql_string] ) :: Q.t
  def group(seq, keys) when is_list(keys), do: %Q{query: [144, [wrap(seq) | Enum.map(keys, &wrap/1)]]}
  def group(seq, key), do: group(seq, [key])

  @doc """
  Takes a grouped stream or grouped data and turns it into an array of objects 
  representing the groups. Any commands chained after ungroup will operate on 
  this array, rather than operating on each group individually. This is useful if 
  you want to e.g. order the groups by the value of their reduction.

  The format of the array returned by ungroup is the same as the default native 
  format of grouped data in the JavaScript driver and data explorer.
  end
  """
  @spec ungroup(Q.t) :: Q.t
  operate_on_single_arg(:ungroup, 150)

  @doc """
  Produce a single value from a sequence through repeated application of a 
  reduction function.

  The reduction function can be called on:

  * two elements of the sequence
  * one element of the sequence and one result of a previous reduction
  * two results of previous reductions

  The reduction function can be called on the results of two previous 
  reductions because the reduce command is distributed and parallelized across 
  shards and CPU cores. A common mistaken when using the reduce command is to 
  suppose that the reduction is executed from left to right.
  """
  @spec reduce(Q.reql_array, Q.reql_func2) :: Q.t
  operate_on_two_args(:reduce, 37)

  @doc """
  Counts the number of elements in a sequence. If called with a value, counts 
  the number of times that value occurs in the sequence. If called with a 
  predicate function, counts the number of elements in the sequence where that 
  function returns `true`.

  If count is called on a binary object, it will return the size of the object 
  in bytes.
  """
  @spec count(Q.reql_array) :: Q.t
  operate_on_single_arg(:count, 43)
  @spec count(Q.reql_array, Q.reql_string | Q.reql_func1) :: Q.t
  operate_on_two_args(:count, 43)
 
  @doc """
  Sums all the elements of a sequence. If called with a field name, sums all 
  the values of that field in the sequence, skipping elements of the sequence 
  that lack that field. If called with a function, calls that function on every 
  element of the sequence and sums the results, skipping elements of the sequence 
  where that function returns `nil` or a non-existence error.

  Returns 0 when called on an empty sequence.
  """
  @spec sum(Q.reql_array) :: Q.t
  operate_on_single_arg(:sum, 145)
  @spec sum(Q.reql_array, Q.reql_string|Q.reql_func1) :: Q.t
  operate_on_two_args(:sum, 145)

  @doc """
  Averages all the elements of a sequence. If called with a field name, 
  averages all the values of that field in the sequence, skipping elements of the 
  sequence that lack that field. If called with a function, calls that function 
  on every element of the sequence and averages the results, skipping elements of 
  the sequence where that function returns None or a non-existence error.

  Produces a non-existence error when called on an empty sequence. You can 
  handle this case with `default`.
  """
  @spec avg(Q.reql_array) :: Q.t
  operate_on_single_arg(:avg, 146)
  @spec avg(Q.reql_array, Q.reql_string|Q.reql_func1) :: Q.t
  operate_on_two_args(:avg, 146)

  @doc """
  Finds the minimum element of a sequence. The min command can be called with:

  * a field name, to return the element of the sequence with the smallest value in 
  that field;
  * an index, to return the element of the sequence with the smallest value in that 
  index;
  * a function, to apply the function to every element within the sequence and 
  return the element which returns the smallest value from the function, ignoring 
  any elements where the function returns None or produces a non-existence error.

  Calling min on an empty sequence will throw a non-existence error; this can be 
  handled using the `default` command.
  """
  @spec min(Q.reql_array, Q.reql_opts | Q.reql_string | Q.reql_func1) :: Q.t
  def min(seq, opts) when is_map(opts), do: %Q{query: [147, [wrap(seq)], opts]}
  operate_on_two_args(:min, 147)
  operate_on_single_arg(:min, 147)

  @doc """
  Finds the maximum element of a sequence. The max command can be called with:

  * a field name, to return the element of the sequence with the smallest value in 
  that field;
  * an index, to return the element of the sequence with the smallest value in that 
  index;
  * a function, to apply the function to every element within the sequence and 
  return the element which returns the smallest value from the function, ignoring 
  any elements where the function returns None or produces a non-existence error.

  Calling max on an empty sequence will throw a non-existence error; this can be 
  handled using the `default` command.
  """
  @spec max(Q.reql_array, Q.reql_opts | Q.reql_string | Q.reql_func1) :: Q.t
  def max(seq, opts) when is_map(opts), do: %Q{query: [148, [wrap(seq)], opts]}
  operate_on_two_args(:max, 148)
  operate_on_single_arg(:max, 148)

  @doc """
  Removes duplicates from elements in a sequence.

  The distinct command can be called on any sequence, a table, or called on a 
  table with an index.
  """
  @spec distinct(Q.reql_array, Q.reql_opts) :: Q.t
  def distinct(seq, opts) when is_map(opts), do: %Q{query: [42, [wrap(seq)], opts]}
  operate_on_single_arg(:distinct, 42)

  @doc """
  When called with values, returns `true` if a sequence contains all the specified 
  values. When called with predicate functions, returns `true` if for each 
  predicate there exists at least one element of the stream where that predicate 
  returns `true`.
  """
  @spec contains(Q.reql_array, Q.reql_array | Q.reql_func1 | Q.t) :: Q.t
  operate_on_seq_and_list(:contains, 93)
  operate_on_two_args(:contains, 93)
end
