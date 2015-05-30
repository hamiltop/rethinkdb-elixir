defmodule RethinkDB.Query.Table do
  alias RethinkDB.Q
  @moduledoc """
  ReQL methods for table manipulation operations.

  All examples assume that `use RethinkDB` has been called.
  """

  require RethinkDB.Query.Macros
  import RethinkDB.Query.Macros
  
  @doc """
  Create a table. A RethinkDB table is a collection of JSON documents.

  If successful, the command returns an object with two fields:

  * tables_created: always 1.
  * config_changes: a list containing one two-field object, old_val and new_val:
    * old_val: always nil.
    * new_val: the table’s new config value.

  If a table with the same name already exists, the command throws 
  RqlRuntimeError.

  Note: Only alphanumeric characters and underscores are valid for the table name.

  When creating a table you can specify the following options:

  * primary_key: the name of the primary key. The default primary key is id.
  * durability: if set to soft, writes will be acknowledged by the server 
    immediately and flushed to disk in the background. The default is hard: 
    acknowledgment of writes happens after data has been written to disk.
  * shards: the number of shards, an integer from 1-32. Defaults to 1.
  * replicas: either an integer or a mapping object. Defaults to 1.
    If replicas is an integer, it specifies the number of replicas per shard. 
    Specifying more replicas than there are servers will return an error.
    If replicas is an object, it specifies key-value pairs of server tags and the 
    number of replicas to assign to those servers: {:tag1 => 2, :tag2 => 4, :tag3 
    => 2, ...}.
  * primary_replica_tag: the primary server specified by its server tag. Required 
    if replicas is an object; the tag must be in the object. This must not be 
    specified if replicas is an integer.
    The data type of a primary key is usually a string (like a UUID) or a number, 
    but it can also be a time, binary object, boolean or an array. It cannot be an 
    object.
  """
  @spec table_create(Q.t, Q.reql_string, Q.reql_opts) :: Q.t
  operate_on_single_arg(:table_create, 60)
  def table_create(name, opt) when is_map(opt), do: %Q{query: [60, [wrap(name)], opt]}
  operate_on_two_args(:table_create, 60)
  def table_create(db, name, opt) when is_map(opt), do: %Q{query: [60, [wrap(db), wrap(name)], opt]}

  @doc """
  Drop a table. The table and all its data will be deleted.

  If successful, the command returns an object with two fields:

  * tables_dropped: always 1.
  * config_changes: a list containing one two-field object, old_val and new_val:
    * old_val: the dropped table’s config value.
    * new_val: always nil.

  If the given table does not exist in the database, the command throws RqlRuntimeError.
  """
  @spec table_drop(Q.t, Q.reql_string) :: Q.t
  operate_on_single_arg(:table_drop, 61)
  operate_on_two_args(:table_drop, 61)

  @doc """
  List all table names in a database. The result is a list of strings.
  """
  @spec table_list(Q.t) :: Q.t
  operate_on_zero_args(:table_list, 62)
  operate_on_single_arg(:table_list, 62)

  @doc """
  Create a new secondary index on a table. Secondary indexes improve the speed of 
  many read queries at the slight cost of increased storage space and decreased 
  write performance. For more information about secondary indexes, read the 
  article “Using secondary indexes in RethinkDB.”

  RethinkDB supports different types of secondary indexes:

  * Simple indexes based on the value of a single field.
  * Compound indexes based on multiple fields.
  * Multi indexes based on arrays of values.
  * Geospatial indexes based on indexes of geometry objects, created when the geo 
    optional argument is true.
  * Indexes based on arbitrary expressions.

  The index_function can be an anonymous function or a binary representation 
  obtained from the function field of index_status.

  If successful, create_index will return an object of the form {:created => 1}. 
  If an index by that name already exists on the table, a RqlRuntimeError will be 
  thrown.
  """
  @spec index_create(Q.t, Q.reql_string, Q.reql_func1, Q.reql_opts) :: Q.t
  operate_on_two_args(:index_create, 75)
  operate_on_three_args(:index_create, 75)

  @doc """
  Delete a previously created secondary index of this table.
  """
  @spec index_drop(Q.t, Q.reql_string) :: Q.t
  operate_on_two_args(:index_drop, 76)

  @doc """
  List all the secondary indexes of this table.
  """
  @spec index_list(Q.t) :: Q.t
  operate_on_single_arg(:index_list, 77)

  @doc """
  Rename an existing secondary index on a table. If the optional argument 
  overwrite is specified as true, a previously existing index with the new name 
  will be deleted and the index will be renamed. If overwrite is false (the 
  default) an error will be raised if the new index name already exists.

  The return value on success will be an object of the format {:renamed => 1}, or 
  {:renamed => 0} if the old and new names are the same.

  An error will be raised if the old index name does not exist, if the new index 
  name is already in use and overwrite is false, or if either the old or new 
  index name are the same as the primary key field name.
  """
  @spec index_rename(Q.t, Q.reql_string, Q.reql_string, Q.reql_opts) :: Q.t
  operate_on_three_args(:index_rename, 156)

  @doc """
  Get the status of the specified indexes on this table, or the status of all 
  indexes on this table if no indexes are specified.
  """
  @spec index_status(Q.t, Q.reql_string|Q.reql_array) :: Q.t
  operate_on_single_arg(:index_status, 139)
  def index_status(table, indexes) when is_list(indexes) do
    %Q{query: [139, [wrap(table) | Enum.map(indexes, &wrap/1)]]}
  end

  @doc """
  Wait for the specified indexes on this table to be ready, or for all indexes on 
  this table to be ready if no indexes are specified.
  """
  @spec index_wait(Q.t, Q.reql_string|Q.reql_array) :: Q.t
  operate_on_single_arg(:index_wait, 140)
  def index_wait(table, indexes) when is_list(indexes) do
    %Q{query: [140, [wrap(table) | Enum.map(indexes, &wrap/1)]]}
  end
end
