Exrethinkdb
===========

Pipeline enabled Rethinkdb client in pure Elixir. Still a work in progress.

###Connection
```elixir
alias Exrethinkdb.Query

conn = Exrethinkdb.local_connection
```
###Query
####Insert
```elixir
q = Query.table("people")
  |> Query.insert(%{first_name: "John", last_name: "Smith"})
Exrethinkdb.run conn, q
```

####Filter
```elixir
q = Query.table("people")
  |> Query.filter(%{last_name: "Smith"})
result = Exrethinkdb.run conn, q
```

See [query.ex](lib/exrethinkdb/query.ex) for more basic queries. If you don't see something supported, please open an issue. We're moving fast and any guidance on desired features is helpful.

###Changes

Change feeds can be consumed either incrementally (by calling `Exrethinkdb.next/1`) or via the Enumerable Protocol.

```elixir
q = Query.table("people")
  |> Query.filter(%{last_name: "Smith"})
  |> Query.changes
results = Exrethinkdb.run conn, q
# get one result
first_change = Exrethinkdb.next results
# get stream, chunked in groups of 5, Inspect
results |> Stream.chunk(5) |> Enum.each &IO.inspect/1
```

###Questions

####Why not use elixir-rethinkdb?
The current state of elixir-rethinkdb (https://github.com/azukiapp/elixir-rethinkdb) is incompatible with rethinkdb 2.0. It also doesn't support pipelining (added in 2.0) for parallel queries. These changes are pretty central to the client, so rather than gutting it, I decided to start from scratch.

A lot of the code from elixir-rethinkdb will probably be useful as we go forward.

Contributions are welcome. The easiest thing to do would be to start updating Exrethinkdb.Query to support the rest of the api. Right now it supports a small subset.
