defmodule RethinkDB do
  @moduledoc """
  Some convenience functions for interacting with RethinkDB.
  """

  @doc """
  See `RethinkDB.Connection.run/2`
  """
  defdelegate run(query, pid), to: RethinkDB.Connection

  @doc """
  See `RethinkDB.Connection.run/3`
  """
  defdelegate run(query, pid, opts), to: RethinkDB.Connection

  @doc """
  See `RethinkDB.Connection.next/1`
  """
  defdelegate next(collection), to: RethinkDB.Connection

  @doc """
  See `RethinkDB.Connection.close/1`
  """
  defdelegate close(collection), to: RethinkDB.Connection
end
