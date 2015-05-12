defmodule RethinkDB.Query.Database do
  alias RethinkDB.Query, as: Q
  @moduledoc """
  ReQL methods for database manipulation operations.

  All examples assume that `use RethinkDB` has been called.
  """

  require RethinkDB.Query.Macros
  import RethinkDB.Query.Macros

  @doc """
  Create a database. A RethinkDB database is a collection of tables, similar to 
  relational databases.

  If successful, the command returns an object with two fields:

  * dbs_created: always 1.
  * config_changes: a list containing one object with two fields, old_val and 
    new_val:
    * old_val: always null.
    * new_val: the database’s new config value.

  If a database with the same name already exists, the command throws 
  RqlRuntimeError.

  Note: Only alphanumeric characters and underscores are valid for the database 
  name.
  """
  @spec db_create(Q.reql_string) :: Q.t
  operate_on_single_arg(:db_create, 57)

  @doc """
  Drop a database. The database, all its tables, and corresponding data will be deleted.

  If successful, the command returns an object with two fields:

  * dbs_dropped: always 1.
  * tables_dropped: the number of tables in the dropped database.
  * config_changes: a list containing one two-field object, old_val and new_val:
    * old_val: the database’s original config value.
    * new_val: always None.

  If the given database does not exist, the command throws RqlRuntimeError.
  """
  @spec db_drop(Q.reql_string) :: Q.t
  operate_on_single_arg(:db_drop, 58)

  @doc """
  List all database names in the system. The result is a list of strings.
  """
  @spec db_list :: Q.t
  operate_on_zero_args(:db_list, 59)
end
