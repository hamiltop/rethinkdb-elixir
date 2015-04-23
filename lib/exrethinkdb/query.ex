defmodule Exrethinkdb.Query do
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

  def filter(query, filter), do: [39, [query, filter]]

  def get(query, id), do: [16, [query,  id]]
  def get_all(query, id, options \\ %{}), do: [78, [query,  id], options]

  def between(lower, upper, options), do: raise "between is not yet implemented"

  def insert(table, object, options \\ %{}), do: [56, [table, object], options]
  def update(selection, object, options \\ %{}), do: [53, [selection, object], options]
  def replace(selection, object, options \\ %{}), do: [55, [selection, object], options]
  def delete(selection, options \\ %{}), do: [54, [selection], options]

  def changes(selection), do: [152, [selection]]
end
