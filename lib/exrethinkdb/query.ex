defmodule Exrethinkdb.Query do
  def make_array(array), do:  [2, array]
  def db(name), do:           [14, [name]]
  def table(name), do:        [15, [name]]
  def table(query, name), do: [15, [query, name]]

  def db_create(name), do:    [57, [name]]
  def db_drop(name), do:      [58, [name]]
  def db_list, do:            [59]

  def table_create(db_query, name, options), do: [60, [db_query, name], options]
  def table_create(name, options = %{}), do: [60, [name], options]
  def table_create(db_query, name), do: [60, [db_query, name]]
  def table_create(name), do: [60, [name]]

  def table_drop(db_query, name), do:   [61, [db_query, name]]
  def table_drop(name), do:   [61, [name]]

  def table_list(db_query), do: [62, [db_query]]
  def table_list, do: [62]

  def filter(query, f) when is_function(f), do: [39, [query, func(f)]]
  def filter(query, filter), do: [39, [query, filter]]

  def get(query, id), do: [16, [query,  id]]
  def get_all(query, id, options \\ %{}), do: [78, [query,  id], options]

  def between(_lower, _upper, _options), do: raise "between is not yet implemented"

  def insert(table, object, options \\ %{})
  def insert(table, object, options) when is_list(object), do: [56, [table, make_array(object)], options]
  def insert(table, object, options), do: [56, [table, object], options]

  def update(selection, object, options \\ %{}), do: [53, [selection, object], options]
  def replace(selection, object, options \\ %{}), do: [55, [selection, object], options]
  def delete(selection, options \\ %{}), do: [54, [selection], options]

  def changes(selection), do: [152, [selection]]

  def pluck(selection, fields), do: [33, [selection | fields]]
  def without(selection, fields), do: [34, [selection | fields]]
  def distinct(sequence), do: [42, [sequence]]
  def count(sequence), do: [43, [sequence]]
  def has_fields(sequence, fields), do:  [32, [sequence, make_array(fields)]]

  def keys(object), do: [94, [object]]

  def merge(objects), do: [35, objects]

  def map(sequence, f), do: [38, [sequence, func(f)]]

  # standard multi arg arithmetic operations
  [
    {:add, 24},
    {:sub, 25},
    {:mul, 26},
    {:div, 27},
    {:eq, 17},
    {:ne, 18},
    {:lt, 19},
    {:le, 20},
    {:gt, 21},
    {:ge, 22}
  ] |> Enum.map fn ({op, opcode}) ->
    def unquote(op)(numA, numB), do: [unquote(opcode), [numA, numB]]
    def unquote(op)(nums) when is_list(nums), do: [unquote(opcode), nums]
  end

  # arithmetic unary ops
  [
    {:not, 23},
    # Not supported yet
    # {:floor, 183},
    # {:ceil, 184},
    # {:round, 185}
  ] |> Enum.map fn ({op, opcode}) ->
    def unquote(op)(val), do: [unquote(opcode), [val]]
  end

  # arithmetic ops that don't fit into the above
  def mod(numA, numB), do: [28, [numA, numB]]

  def func(f) when is_function(f) do
    {_, arity} = :erlang.fun_info(f, :arity)

    args = Enum.map(1..arity, fn _ -> make_ref end)
    params = Enum.map(args, &([10, [&1]]))
    res = case apply(f, params) do
      x -> x
    end
    [69, [[2, args], res]]
  end

  def bracket(obj, key), do: [170, [obj, key]]
end
