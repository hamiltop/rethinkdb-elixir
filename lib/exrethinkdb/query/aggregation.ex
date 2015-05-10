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
end
