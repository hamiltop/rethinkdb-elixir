defmodule RethinkDB.Query.Selection do
  alias RethinkDB.Query, as: Q
  @moduledoc """
  ReQL methods for selecting data.
  """

  require RethinkDB.Query.Macros
  import RethinkDB.Query.Macros

  @doc """
  Reference a database.
  """
  @spec db(Q.reql_string) :: Q.t
  operate_on_single_arg(:db, 14)

  @doc """
  Return all documents in a table. Other commands may be chained after table to 
  return a subset of documents (such as get and filter) or perform further 
  processing.

  There are two optional arguments.

  * useOutdated: if true, this allows potentially out-of-date data to be returned, 
    with potentially faster reads. It also allows you to perform reads from a 
    secondary replica if a primary has failed. Default false.
  * identifierFormat: possible values are name and uuid, with a default of name. If 
    set to uuid, then system tables will refer to servers, databases and tables by 
    UUID rather than name. (This only has an effect when used with system tables.)
  """
  @spec table(Q.reql_string, Q.reql_opts) :: Q.t
  @spec table(Q.t, Q.reql_string, Q.reql_opts) :: Q.t
  operate_on_single_arg(:table, 15)
  operate_on_two_args(:table, 15)

  @doc """
  Get a document by primary key.

  If no document exists with that primary key, get will return nil.
  """
  @spec get(Q.t, Q.reql_datum) :: Q.t
  operate_on_two_args(:get, 16)

  @doc """
  Get all documents where the given value matches the value of the requested index.
  """
  @spec get_all(Q.t, Q.reql_array) :: Q.t
  operate_on_seq_and_list(:get_all, 78)
  
end
