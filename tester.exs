alias RethinkDB.Query

a = RethinkDB.local_connection
b = RethinkDB.run(a, Query.table("people") |> Query.changes)

b |> Enum.each fn (el) ->
  IO.inspect el
end
