Exrethinkdb
===========

Pipeline enabled Rethinkdb client in pure Elixir. Still a work in progress.

###Questions

####Why not use elixir-rethinkdb?
The current state of elixir-rethinkdb (https://github.com/azukiapp/elixir-rethinkdb) is incompatible with rethinkdb 2.0. It also doesn't support pipelining (added in 2.0) for parallel queries. These changes are pretty central to the client, so rather than gutting it, I decided to start from scratch.

A lot of the code from elixir-rethinkdb will probably be useful as we go forward.

Contributions are welcome. The easiest thing to do would be to start updating Exrethinkdb.Query to support the rest of the api. Right now it supports a small subset.
