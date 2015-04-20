defmodule Exrethinkdb.Query do
  def db(name), do:           [14, [name]]
  def table(name), do:        [15, [name]]
  def table(query, name), do: [15, [query, name]]

  def filter(query, filter), do: [39, [query, filter]]

  def get(query, id), do: [16, [query,  id]]
  def get_all(query, id, options \\ %{}), do: [78, [query,  id], options]

  def between(lower, upper, options), do: raise "between is not yet implemented"

  def insert(table, object, options \\ %{}), do: [56, [table, object], options]
  def update(selection, object, options \\ %{}), do: [53, [selection, object], options]
  def replace(selection, object, options \\ %{}), do: [55, [selection, object], options]
  def delete(selection, options \\ %{}), do: [54, [selection], options]
end
