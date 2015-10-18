defmodule RethinkDB do

  defmacro __using__(_opts) do
    quote do
      import RethinkDB.Query
      import RethinkDB
    end
  end

  defdelegate connect(), to: RethinkDB.Connection
  defdelegate connect(opts), to: RethinkDB.Connection
  defdelegate run(query, pid), to: RethinkDB.Connection
  defdelegate run(query, pid, timeout), to: RethinkDB.Connection
  defdelegate next(collection), to: RethinkDB.Connection

end
