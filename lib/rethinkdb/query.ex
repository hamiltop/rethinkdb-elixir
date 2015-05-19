defmodule RethinkDB.Query do
  alias __MODULE__, as: Q
  defstruct query: nil

  @type t :: %Q{}
  @type reql_string :: String.t|t
  @type reql_number :: integer|float|t
  @type reql_array  :: [term]|t
  @type reql_bool   :: boolean|t
  @type reql_obj    :: %{}|t
  @type reql_datum  :: term
  @type reql_func0  :: (() -> term)|t
  @type reql_func1  :: (term -> term)|t
  @type reql_func2  :: (term, term -> term)|t
  @type reql_opts   :: %{}
  @type reql_binary :: %RethinkDB.Pseudotypes.Binary{}|binary|t

  defmacro __using__(_opts) do
    quote do
      import RethinkDB.Query.StringManipulation
      import RethinkDB.Query.MathLogic
      import RethinkDB.Query.Joins
      import RethinkDB.Query.Aggregation
      import RethinkDB.Query.Database
      import RethinkDB.Query.Table
      import RethinkDB.Query.WritingData
      import RethinkDB.Query.ControlStructures
      import RethinkDB.Query
    end
  end

  def make_array(array), do:  %Q{query: [2, array]}

  def db(name), do:           %Q{query: [14, [name]]}
  def table(name), do:        %Q{query: [15, [name]]}
  def table(query, name), do: %Q{query: [15, [query, name]]}

  def filter(query, f) when is_list(query), do: filter(make_array(query), f)
  def filter(query, f) when is_function(f), do: %Q{query: [39, [query, func(f)]]}
  def filter(query, filter), do: %Q{query: [39, [query, filter]]}

  def get(query, id), do: %Q{query: [16, [query,  id]]}
  def get_all(query, id, options \\ %{}), do: %Q{query: [78, [query,  id], options]}

  def between(query, lower, upper, options \\ %{}), do: [182, [query, lower, upper, options]]

  def changes(selection), do: %Q{query: [152, [selection]]}

  def get_field(seq, field) when is_list(seq), do: get_field(make_array(seq), field)
  def get_field(seq, field), do: %Q{query: [31, [seq, field]]}
  def keys(object), do: %Q{query: [94, [object]]}

  def pluck(seq, f) when is_list(seq), do: pluck(make_array(seq), f)
  def pluck(selection, fields) when is_list(fields), do: %Q{query: [33, [selection | fields]]}
  def pluck(selection, field), do: %Q{query: [33, [selection, field]]}
  def without(selection, fields), do: %Q{query: [34, [selection | fields]]}
  def has_fields(sequence, fields), do:  %Q{query: [32, [sequence, make_array(fields)]]}

  def merge(objects), do: %Q{query: [35, objects]}

  def map(seq, f) when is_list(seq), do: map(make_array(seq), f)
  def map(sequence, f), do: %Q{query: [38, [sequence, func(f)]]}
  def flat_map(sequence, f), do: %Q{query: [40, [sequence, func(f)]]}
  def concat_map(sequence, f), do: flat_map(sequence, f)

  def order_by(sequence, order), do: order_by(sequence, order, %{})
  def order_by(sequence, order, options) when is_list(order), do: %Q{query: [41, [sequence | order], options]}
  def order_by(sequence, order, options), do: %Q{query: [41, [sequence, order], options]}

  def append(array, datum), do: %Q{query: [29, [array, datum]]}
  def prepend(array, datum), do: %Q{query: [30, [array, datum]]}
  def difference(arrayA, arrayB), do: %Q{query: [95, [arrayA, arrayB]]}

  def slice(seq, start, end_el) when is_list(seq), do: slice(make_array(seq), start, end_el)
  def slice(seq, start, end_el), do: %Q{query: [30, [seq, start, end_el]]}
  def skip(seq, count) when is_list(seq), do: skip(make_array(seq), count)
  def skip(seq, count), do: %Q{query: [70, [seq, count]]}
  def limit(seq, count) when is_list(seq), do: limit(make_array(seq), count)
  def limit(seq, count), do: %Q{query: [71, [seq, count]]}
  def offsets_of(seq, el) when is_list(seq), do: offsets_of(make_array(seq), el)
  def offsets_of(seq, f) when is_function(f), do: %Q{query: [87, [seq, func(f)]]}
  def offsets_of(seq, el), do: %Q{query: [87, [seq, el]]}
  def asc(key), do: %Q{query: [73, [key]]}
  def desc(key), do: %Q{query: [74, [key]]}

  def func(f) when is_function(f) do
    {_, arity} = :erlang.fun_info(f, :arity)

    args = case arity do
      0 -> []
      _ -> Enum.map(1..arity, fn _ -> make_ref end)
    end
    params = Enum.map(args, &var/1)

    res = case apply(f, params) do
      x when is_list(x) -> make_array(x)
      x -> x
    end
    %Q{query: [69, [[2, args], res]]}
  end

  def var(val), do: %Q{query: [10, [val]]}
  def bracket(obj, key), do: %Q{query: [170, [obj, key]]}
end
defimpl Poison.Encoder, for: RethinkDB.Query do
  def encode(%{query: query}, options) do
    Poison.Encoder.encode(query, options)
  end
end
defimpl Access, for: RethinkDB.Query do
  def get(%{query: query}, term) do
    RethinkDB.Query.bracket(query, term)
  end
  def get_and_update(_,_,_), do: raise "get_and_update not supported"
end
