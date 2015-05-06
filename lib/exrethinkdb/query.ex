defmodule Exrethinkdb.Query do
  alias __MODULE__, as: Q
  defstruct query: nil

  @type t :: %Q{}
  @type reql_string :: (String.t|%Q{})
  @type reql_number :: (integer|float|%Q{})
  @type reql_array :: ([term]|%Q{})
  @type reql_bool :: (boolean|%Q{})
  @type reql_datum :: term

  defmacro __using__(_opts) do
    quote do
      import Exrethinkdb.Query.StringManipulation
      import Exrethinkdb.Query.MathLogic
      import Exrethinkdb.Query
    end
  end

  def make_array(array), do:  %Q{query: [2, array]}

  def db(name), do:           %Q{query: [14, [name]]}
  def table(name), do:        %Q{query: [15, [name]]}
  def table(query, name), do: %Q{query: [15, [query, name]]}

  def db_create(name), do:    %Q{query: [57, [name]]}
  def db_drop(name), do:      %Q{query: [58, [name]]}
  def db_list, do:            %Q{query: [59]}

  def table_create(db_query, name, options), do: %Q{query: [60, [db_query, name], options]}
  def table_create(name, options = %{}), do: %Q{query: [60, [name], options]}
  def table_create(db_query, name), do: %Q{query: [60, [db_query, name]]}
  def table_create(name), do: %Q{query: [60, [name]]}

  def table_drop(db_query, name), do:   %Q{query: [61, [db_query, name]]}
  def table_drop(name), do:   %Q{query: [61, [name]]}

  def table_list(db_query), do: %Q{query: [62, [db_query]]}
  def table_list, do: %Q{query: [62]}

  def filter(query, f) when is_list(query), do: filter(make_array(query), f)
  def filter(query, f) when is_function(f), do: %Q{query: [39, [query, func(f)]]}
  def filter(query, filter), do: %Q{query: [39, [query, filter]]}

  def get(query, id), do: %Q{query: [16, [query,  id]]}
  def get_all(query, id, options \\ %{}), do: %Q{query: [78, [query,  id], options]}

  def between(query, lower, upper, options \\ %{}), do: [182, [query, lower, upper, options]]

  def insert(table, object, options \\ %{})
  def insert(table, object, options) when is_list(object), do: %Q{query: [56, [table, make_array(object)], options]}
  def insert(table, object, options), do: %Q{query: [56, [table, object], options]}

  def update(selection, object, options \\ %{}), do: %Q{query: [53, [selection, object], options]}
  def replace(selection, object, options \\ %{}), do: %Q{query: [55, [selection, object], options]}
  def delete(selection, options \\ %{}), do: %Q{query: [54, [selection], options]}

  def changes(selection), do: %Q{query: [152, [selection]]}

  def get_field(seq, field) when is_list(seq), do: get_field(make_array(seq), field)
  def get_field(seq, field), do: %Q{query: [31, [seq, field]]}
  def keys(object), do: %Q{query: [94, [object]]}

  def pluck(seq, f) when is_list(seq), do: pluck(make_array(seq), f)
  def pluck(selection, fields) when is_list(fields), do: %Q{query: [33, [selection | fields]]}
  def pluck(selection, field), do: %Q{query: [33, [selection, field]]}
  def without(selection, fields), do: %Q{query: [34, [selection | fields]]}
  def distinct(sequence), do: %Q{query: [42, [sequence]]}
  def has_fields(sequence, fields), do:  %Q{query: [32, [sequence, make_array(fields)]]}

  def merge(objects), do: %Q{query: [35, objects]}

  def map(seq, f) when is_list(seq), do: map(make_array(seq), f)
  def map(sequence, f), do: %Q{query: [38, [sequence, func(f)]]}
  def reduce(sequence, f), do: %Q{query: [37, [sequence, func(f)]]}
  def flat_map(sequence, f), do: %Q{query: [40, [sequence, func(f)]]}
  def concat_map(sequence, f), do: flat_map(sequence, f)

  def order_by(sequence, order), do: order_by(sequence, order, %{})
  def order_by(sequence, order, options) when is_list(order), do: %Q{query: [41, [sequence | order], options]}
  def order_by(sequence, order, options), do: %Q{query: [41, [sequence, order], options]}

  def count(sequence), do: %Q{query: [43, [sequence]]}
  def count(sequence, f) when is_function(f), do: %Q{query: [43, [sequence, func(f)]]}
  def count(sequence, d), do: %Q{query: [43, [sequence, d]]}

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
  def contains(seq, data) when is_list(seq), do: contains(make_array(seq), data)
  def contains(seq, list) when is_list(list) do
    data = list |> Enum.map(fn
      f when is_function(f) -> func(f)
      x -> x
    end)
    %Q{query: [93, [seq | data]]}
  end
  def contains(seq, f) when is_function(f), do: contains(seq, func(f))
  # TODO: contains with multiple functions
  def contains(seq, el), do: %Q{query: [93, [seq, el]]}
  def asc(key), do: %Q{query: [73, [key]]}
  def desc(key), do: %Q{query: [74, [key]]}

  def branch(expr, truthy, falsy), do: %Q{query: [65, [expr, truthy, falsy]]}

  def func(f) when is_function(f) do
    {_, arity} = :erlang.fun_info(f, :arity)

    args = Enum.map(1..arity, fn _ -> make_ref end)
    params = Enum.map(args, &var/1)
    res = case apply(f, params) do
      x when is_list(x) -> make_array(x)
      x -> x
    end
    %Q{query: [69, [[2, args], res]]}
  end

  def var(val), do: %Q{query: [10, [val]]}
  def bracket(obj, key), do: %Q{query: [170, [obj, key]]}

  def prepare(query) do
    %{query: prepared_query} = prepare(query, %{query: [], vars: {0, %{}}})
    prepared_query
  end
  def prepare(%Q{query: query}, acc), do: prepare(query, acc)
  def prepare([h | t], %{query: query, vars: vars}) do
    %{query: new_query, vars: new_vars} = prepare(h, %{query: [], vars: vars})
    prepare(t, %{query: query ++ [new_query], vars: new_vars})
  end
  def prepare([], acc) do
    acc
  end
  def prepare(ref, %{query: query, vars: {max, map}}) when is_reference(ref) do
    case Dict.get(map, ref) do
      nil ->
        %{
          query: query ++ (max + 1),
          vars: {max + 1, Dict.put_new(map, ref, max + 1)}
        }
      x ->
        %{
          query: query ++ x,
          vars: {max, map}
        }
    end
  end
  def prepare(el, %{query: query, vars: vars}) do
    %{query: query ++ el, vars: vars}
  end
end
defimpl Poison.Encoder, for: Exrethinkdb.Query do
  def encode(%{query: query}, options) do
    Poison.Encoder.encode(query, options)
  end
end
defimpl Access, for: Exrethinkdb.Query do
  def get(%{query: query}, term) do
    Exrethinkdb.Query.bracket(query, term)
  end
  def get_and_update(_,_,_), do: raise "get_and_update not supported"
end
