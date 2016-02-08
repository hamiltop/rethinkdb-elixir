RethinkDB [![Build Status](https://travis-ci.org/hamiltop/rethinkdb-elixir.svg?branch=master)](https://travis-ci.org/hamiltop/rethinkdb-elixir)
===========
Multiplexed RethinkDB client in pure Elixir.

If you are coming here from elixir-rethinkdb, welcome!
If you were expecting `Exrethinkdb` you are in the right place. We decided to change the name to just `RethinkDB` and the repo to `rethinkdb-elixir`. Sorry if it has caused confusion. Better now in the early stages than later!

I just set up a channel on the Elixir slack, so if you are on there join #rethinkdb.

###Recent changes

####0.2.0
* Pruned a lot of connection calls that were public.
* Added exponential backoff to connection
* Added supervised changefeeds
* Pruned and polished docs

##Getting Started

See [API documentation](http://hexdocs.pm/rethinkdb/) for more details.

###Connection

Connections are managed by a process. Start the process by calling `start_link/1`. See [documentation for `Connection.start_link/1`](http://hexdocs.pm/rethinkdb/RethinkDB.Connection.html#start_link/1) for supported options. 

####Basic Remote Connection
```elixir
{:ok, conn} = RethinkDB.Connection.start_link([host: "10.0.0.17", port: 28015])
```

####Named Connection
```elixir
{:ok, conn} = RethinkDB.Connection.start_link([name: :foo]})
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
worker(FooDatabase, [])
```
Queries can be run without providing a connection (it will use the name connection).
```elixir
import RethinkDB.Query
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
###Supervised Changefeeds

Changefeeds have been moved to their own repo to enable independent release
cycles. See https://github.com/hamiltop/rethinkdb_changefeed

###Roadmap
Version 1.0.0 will be limited to individual connections and implement the entire documented ReQL (as of rethinkdb 2.0)

While not provided by this library, we will also include example code for:

* Connection Pooling

The goal for 1.0.0 is to be stable. Issues have been filed for work that needs to be completed before 1.0.0 and tagged with the 1.0.0 milestone.


###Example Apps
Checkout the wiki page for various [example apps](https://github.com/hamiltop/rethinkdb-elixir/wiki/Example-Apps)


###Contributing
Contributions are welcome. Take a look at the Issues. Anything that is tagged `Help Wanted` or `Feedback Wanted` is a good candidate for contributions. Even if you don't know where to start, respond to an interesting issue and you will be pointed in the right direction.

####Testing
Be intentional. Whether you are writing production code or tests, make sure there is value in the test being written.
