defmodule Exrethinkdb.Query.WritingData do
  alias Exrethinkdb.Query, as: Q

  require Exrethinkdb.Query.Macros
  import Exrethinkdb.Query.Macros

  @doc """
  Insert documents into a table. Accepts a single document or an array of 
  documents.

  The optional arguments are:

  * durability: possible values are hard and soft. This option will override the 
    table or query’s durability setting (set in run). In soft durability mode 
    Rethink_dB will acknowledge the write immediately after receiving and caching 
    it, but before the write has been committed to disk.
  * return_changes: if set to True, return a changes array consisting of 
    old_val/new_val objects describing the changes made.
  * conflict: Determine handling of inserting documents with the same primary key 
    as existing entries. Possible values are "error", "replace" or "update".
    * "error": Do not insert the new document and record the conflict as an error. 
      This is the default.
    * "replace": Replace the old document in its entirety with the new one.
    * "update": Update fields of the old document with fields from the new one.

  Insert returns an object that contains the following attributes:

  * inserted: the number of documents successfully inserted.
  * replaced: the number of documents updated when conflict is set to "replace" or 
    "update".
  * unchanged: the number of documents whose fields are identical to existing 
    documents with the same primary key when conflict is set to "replace" or 
    "update".
  * errors: the number of errors encountered while performing the insert.
  * first_error: If errors were encountered, contains the text of the first error.
  * deleted and skipped: 0 for an insert operation.
  * generated_keys: a list of generated primary keys for inserted documents whose 
    primary keys were not specified (capped to 100,000).
  * warnings: if the field generated_keys is truncated, you will get the warning 
    “Too many generated keys (<X>), array truncated to 100000.”.
  * changes: if return_changes is set to True, this will be an array of objects, 
    one for each objected affected by the insert operation. Each object will have 
  * two keys: {"new_val": <new value>, "old_val": None}.
  """
  @spec insert(Q.t, Q.reql_obj | Q.reql_array, %{}) :: Q.t
  def insert(table, object, options \\ %{}) do
    %Q{query: [56, [wrap(table), wrap(object)], options]}
  end
end
