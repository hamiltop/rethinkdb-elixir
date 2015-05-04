Exrethinkdb
===========

Pipeline enabled Rethinkdb client in pure Elixir. Still a work in progress.

###Connection

Connections are managed by a GenServer. The GenServer will register itself with a default name. If you want multiple connections on a node, be sure to give them explicit names or set the name to `nil` to make it skip registration.

####Basic Local Connection
```elixir
alias Exrethinkdb.Query

conn = Exrethinkdb.connect
```

####Basic Remote Connection
```elixir
conn = Exrethinkdb.connect([host: "10.0.0.17", port: 28015])
```

####Named Connection
```elixir
conn = Exrethinkdb.connect([name: :foo]})
```

####Supervised Connection
Start the supervisor with:
```elixir
worker(Exrethinkdb.Connection, [])
worker(Exrethinkdb.Connection, [[name: :foo]])
worker(Exrethinkdb.Connection, [[name: :bar, host: 'localhost', port: 28015]])
```

###Query
`Exrethinkdb.run/1` will use the default registered connection. `Exrethinkdb.run/2` accepts a process as the first argument.

####Insert
```elixir

q = Query.table("people")
  |> Query.insert(%{first_name: "John", last_name: "Smith"})
# Default connection
Exrethinkdb.run q
# Run on unnamed connection
Exrethinkdb.run conn, q
```

####Filter
```elixir
q = Query.table("people")
  |> Query.filter(%{last_name: "Smith"})
result = Exrethinkdb.run q
```

####Functions
Exrethinkdb supports RethinkDB functions in queries. There are two approaches you can take:

Use RethinkDB operators
```elixir
import Exrethinkdb.Query

make_array([1,2,3]) |> map(fn (x) -> add(x, 1) end)
```

Use Elixir operators via the lambda macro
```elixir
require Exrethinkdb.Lambda
import Exrethinkdb.Lambda

make_array([1,2,3]) |> map(lambda fn (x) -> x + 1 end)
```

####Map
```elixir
require Exrethinkdb.Lambda
import Query
import Exrethinkdb.Lambda

table("people")
  |> has_fields(["first_name", "last_name"])
  |> map(lambda fn (person) ->
    person[:first_name] + " " + person[:last_name]
  end) |> Exrethinkdb.run
```



See [query.ex](lib/exrethinkdb/query.ex) for more basic queries. If you don't see something supported, please open an issue. We're moving fast and any guidance on desired features is helpful.

###Changes

Change feeds can be consumed either incrementally (by calling `Exrethinkdb.next/1`) or via the Enumerable Protocol.

```elixir
q = Query.table("people")
  |> Query.filter(%{last_name: "Smith"})
  |> Query.changes
results = Exrethinkdb.run q
# get one result
first_change = Exrethinkdb.next results
# get stream, chunked in groups of 5, Inspect
results |> Stream.chunk(5) |> Enum.each &IO.inspect/1
```

###Questions

####Why not use elixir-rethinkdb?
The current state of elixir-rethinkdb (https://github.com/azukiapp/elixir-rethinkdb) is incompatible with rethinkdb 2.0. It also doesn't support pipelining (added in 2.0) for parallel queries. These changes are pretty central to the client, so rather than gutting it, I decided to start from scratch.

A lot of the code from elixir-rethinkdb will probably be useful as we go forward.

###Contributing
Contributions are welcome. The easiest thing to do would be to start updating Exrethinkdb.Query to support the rest of the api. Right now it supports a small subset.

####Testing
I'm a little unorthodox when it comes to testing. Testing complex logic is good. Testing "Did I type that line correctly?" is less good.

Right now there are some rough tests in place that use a local rethinkdb instance. If you are doing something complicated, then writing a test there is better than nothing. If you are merely adding another function to `Exrethinkdb.Query` and you are copying directly from the spec, then a test isn't going to be that useful.

All that said, each new feature has characteristics that influence testing. Take everything on a case by case basis.
