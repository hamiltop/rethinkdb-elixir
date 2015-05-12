RethinkDB [![Build Status](https://travis-ci.org/hamiltop/exrethinkdb.svg?branch=master)](https://travis-ci.org/hamiltop/exrethinkdb)
===========

Pipeline enabled Rethinkdb client in pure Elixir. Still a work in progress.

###Connection

Connections are managed by a GenServer. The GenServer will register itself with a default name. If you want multiple connections on a node, be sure to give them explicit names or set the name to `nil` to make it skip registration.

####Basic Local Connection
```elixir
alias RethinkDB.Query

conn = RethinkDB.connect
```

####Basic Remote Connection
```elixir
conn = RethinkDB.connect([host: "10.0.0.17", port: 28015])
```

####Named Connection
```elixir
conn = RethinkDB.connect([name: :foo]})
```

####Supervised Connection
Start the supervisor with:
```elixir
worker(RethinkDB.Connection, [[name: :foo]])
worker(RethinkDB.Connection, [[name: :bar, host: 'localhost', port: 28015]])
```

####Default Connection
An `RethinkDB.Connection` does parallel queries via pipelining. It can and should be shared among multiple processes. Because of this, it is common to have one connection shared in your application. To create a default connection, we create a new module and `use RethinkDB.Connection`.
```elixir
defmodule FooDatabase do
  use RethinkDB.Connection
end
```
This connection can be supervised without a name (it will assume the module as the name).
```elixir
worker(RethinkDB.Connection, [])
```
Queries can be run without providing a connection (it will use the name connection).
```elixir
use RethinkDB.Query
table("people") |> FooDatabase.run
```

###Query
`RethinkDB.run/2` accepts a process as the second argument (to facilitate piping).

####Insert
```elixir

q = Query.table("people")
  |> Query.insert(%{first_name: "John", last_name: "Smith"})
  |> RethinkDB.run conn
```

####Filter
```elixir
q = Query.table("people")
  |> Query.filter(%{last_name: "Smith"})
  |> RethinkDB.run conn
```

####Functions
RethinkDB supports RethinkDB functions in queries. There are two approaches you can take:

Use RethinkDB operators
```elixir
import RethinkDB.Query

make_array([1,2,3]) |> map(fn (x) -> add(x, 1) end)
```

Use Elixir operators via the lambda macro
```elixir
require RethinkDB.Lambda
import RethinkDB.Lambda

make_array([1,2,3]) |> map(lambda fn (x) -> x + 1 end)
```

####Map
```elixir
require RethinkDB.Lambda
import Query
import RethinkDB.Lambda

conn = RethinkDB.connect

table("people")
  |> has_fields(["first_name", "last_name"])
  |> map(lambda fn (person) ->
    person[:first_name] + " " + person[:last_name]
  end) |> RethinkDB.run conn
```

See [query.ex](lib/rethinkdb/query.ex) for more basic queries. If you don't see something supported, please open an issue. We're moving fast and any guidance on desired features is helpful.

###Changes

Change feeds can be consumed either incrementally (by calling `RethinkDB.next/1`) or via the Enumerable Protocol.

```elixir
q = Query.table("people")
  |> Query.filter(%{last_name: "Smith"})
  |> Query.changes
  |> RethinkDB.run conn
# get one result
first_change = RethinkDB.next results
# get stream, chunked in groups of 5, Inspect
results |> Stream.chunk(5) |> Enum.each &IO.inspect/1
```

###Shortcuts

Calling `use RethinkDB` will import all functions into the current scope. If you are using a custom connection, using that connection module will import all functions into the current scope. If you use both `RethinkDB` and your custom connection, you will have a namespace clash.

###Questions

####Why not use elixir-rethinkdb?
The current state of elixir-rethinkdb (https://github.com/azukiapp/elixir-rethinkdb) is incompatible with rethinkdb 2.0. It also doesn't support pipelining (added in 2.0) for parallel queries. These changes are pretty central to the client, so rather than gutting it, I decided to start from scratch.

A lot of the code from elixir-rethinkdb will probably be useful as we go forward.

###Roadmap
Version 1.0.0 will be limited to individual connections and implement the entire documented ReQL (as of rethinkdb 2.0)

While not provided by this library, we will also include example code for:

* Connection Pooling
* Supervised Feeds

The goal for 1.0.0 is to be stable. Issues have been filed for work that needs to be completed before 1.0.0 and tagged with the 1.0.0 milestone.

###Contributing
Contributions are welcome. Take a look at the Issues. Anything that is tagged `Help Wanted` or `Feedback Wanted` is a good candidate for contributions. Even if you don't know where to start, respond to an interesting issue and you will be pointed in the right direction.

####Testing
Be intentional. Whether you are writing production code or tests, make sure there is value in the test being writtne.
