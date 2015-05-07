defmodule Exrethinkdb.Query.Joins do
  alias Exrethinkdb.Query, as: Q
  @moduledoc """
  ReQL methods for join operations.

  All examples assume that `use Exrethinkdb` has been called.
  """

  require Exrethinkdb.Query.Macros
  import Exrethinkdb.Query.Macros

  @doc """
  Returns an inner join of two sequences. The returned sequence represents an
  intersection of the left-hand sequence and the right-hand sequence: each row of
  the left-hand sequence will be compared with each row of the right-hand
  sequence to find all pairs of rows which satisfy the predicate. Each matched
  pair of rows of both sequences are combined into a result row. In most cases,
  you will want to follow the join with `zip` to combine the left and right results.

  Note that `inner_join` is slower and much less efficient than using `eqJoin` or
  `flat_map` with `get_all`. You should avoid using `inner_join` in commands when
  possible.

      iex> table("people") |> inner_join(
          table("phone_numbers"), &(eq(&1["id"], &2["person_id"])
        ) |> run

  """
  @spec inner_join(Q.reql_array, Q.reql_array, Q.reql_func2) :: Q.t
  def inner_join(left, right, f), do: %Q{query: [48, [wrap(left), wrap(right), Q.func(f)]]}

  @doc """
  Returns a left outer join of two sequences. The returned sequence represents
  a union of the left-hand sequence and the right-hand sequence: all documents in
  the left-hand sequence will be returned, each matched with a document in the
  right-hand sequence if one satisfies the predicate condition. In most cases,
  you will want to follow the join with `zip` to combine the left and right results.

  Note that `outer_join` is slower and much less efficient than using `flat_map`
  with `get_all`. You should avoid using `outer_join` in commands when possible.

      iex> table("people") |> outer_join(
          table("phone_numbers"), &(eq(&1["id"], &2["person_id"])
        ) |> run

  """
  @spec outer_join(Q.reql_array, Q.reql_array, Q.reql_func2) :: Q.t
  def outer_join(left, right, f), do: %Q{query: [49, [wrap(left), wrap(right), Q.func(f)]]}
  @doc """
  Join tables using a field on the left-hand sequence matching primary keys or
  secondary indexes on the right-hand table. `eq_join` is more efficient than other
  ReQL join types, and operates much faster. Documents in the result set consist
  of pairs of left-hand and right-hand documents, matched when the field on the
  left-hand side exists and is non-null and an entry with that field’s value
  exists in the specified index on the right-hand side.

  The result set of `eq_join` is a stream or array of objects. Each object in the
  returned set will be an object of the form `{ left: <left-document>, right:
  <right-document> }`, where the values of left and right will be the joined
  documents. Use the zip command to merge the left and right fields together.

      iex> table("people") |> eq_join(
          "id", table("phone_numbers"), %{index: "person_id"}
        ) |> run

  """
  @spec eq_join(Q.reql_array, Q.reql_string, Q.reql_array, %{}) :: Q.t
  def eq_join(left, field, right, opts \\ %{}) do
    %Q{query: [50, [wrap(left), field, wrap(right)], opts]}
  end

  @doc """
  Used to ‘zip’ up the result of a join by merging the ‘right’ fields into
  ‘left’ fields of each member of the sequence.

      iex> table("people") |> eq_join(
          "id", table("phone_numbers"), %{index: "person_id"}
        ) |> zip |> run

  """
  @spec zip(Q.reql_array) :: Q.t
  operate_on_single_arg(:zip, 72)
end
