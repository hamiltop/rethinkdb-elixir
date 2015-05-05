defmodule Exrethinkdb do

  defmacro __using__(_opts) do
    quote do
      use Exrethinkdb.Query
      import Exrethinkdb
    end
  end

  defdelegate connect(), to: Exrethinkdb.Connection
  defdelegate connect(opts), to: Exrethinkdb.Connection
  defdelegate run(query, pid), to: Exrethinkdb.Connection
  defdelegate next(collection), to: Exrethinkdb.Connection
  defdelegate prepare_and_encode(query), to: Exrethinkdb.Connection

end
