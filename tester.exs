alias Exrethinkdb.Query

a = Exrethinkdb.local_connection
b = Exrethinkdb.run(a, Query.table("people") |> Query.changes)

b |> Enum.each fn (el) ->
  IO.inspect el
end
