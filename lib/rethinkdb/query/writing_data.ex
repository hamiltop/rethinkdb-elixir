defmodule RethinkDB.Query.WritingData do
  alias RethinkDB.Query, as: Q

  require RethinkDB.Query.Macros
  import RethinkDB.Query.Macros

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
  operate_on_two_args(:insert, 56)

  @doc """
  Update JSON documents in a table. Accepts a JSON document, a ReQL expression, 
  or a combination of the two.

  The optional arguments are:

  * durability: possible values are hard and soft. This option will override the 
    table or query’s durability setting (set in run). In soft durability mode 
    RethinkDB will acknowledge the write immediately after receiving it, but before 
    the write has been committed to disk.
  * return_changes: if set to True, return a changes array consisting of 
    old_val/new_val objects describing the changes made.
  * non_atomic: if set to True, executes the update and distributes the result to 
    replicas in a non-atomic fashion. This flag is required to perform 
    non-deterministic updates, such as those that require reading data from another 
    table.

  Update returns an object that contains the following attributes:

  * replaced: the number of documents that were updated.
  * unchanged: the number of documents that would have been modified except the new 
    value was the same as the old value.
  * skipped: the number of documents that were skipped because the document didn’t 
    exist.
  * errors: the number of errors encountered while performing the update.
  * first_error: If errors were encountered, contains the text of the first error.
  * deleted and inserted: 0 for an update operation.
  * changes: if return_changes is set to True, this will be an array of objects, 
    one for each objected affected by the update operation. Each object will have 
  * two keys: {"new_val": <new value>, "old_val": <old value>}.
  """
  @spec update(Q.t, Q.reql_obj, %{}) :: Q.t
  operate_on_two_args(:update, 53)

  @doc """
  Replace documents in a table. Accepts a JSON document or a ReQL expression, and 
  replaces the original document with the new one. The new document must have the 
  same primary key as the original document.

  The optional arguments are:

  * durability: possible values are hard and soft. This option will override the 
    table or query’s durability setting (set in run).
    In soft durability mode RethinkDB will acknowledge the write immediately after 
    receiving it, but before the write has been committed to disk.
  * return_changes: if set to True, return a changes array consisting of 
    old_val/new_val objects describing the changes made.
  * non_atomic: if set to True, executes the replacement and distributes the result 
    to replicas in a non-atomic fashion. This flag is required to perform 
    non-deterministic updates, such as those that require reading data from another 
    table.

  Replace returns an object that contains the following attributes:

  * replaced: the number of documents that were replaced
  * unchanged: the number of documents that would have been modified, except that 
    the new value was the same as the old value
  * inserted: the number of new documents added. You can have new documents 
    inserted if you do a point-replace on a key that isn’t in the table or you do a 
    replace on a selection and one of the documents you are replacing has been 
    deleted
  * deleted: the number of deleted documents when doing a replace with None
  * errors: the number of errors encountered while performing the replace.
  * first_error: If errors were encountered, contains the text of the first error.
  * skipped: 0 for a replace operation
  * changes: if return_changes is set to True, this will be an array of objects, 
    one for each objected affected by the replace operation. Each object will have 
  * two keys: {"new_val": <new value>, "old_val": <old value>}.
  """
  @spec replace(Q.t, Q.reql_obj, %{}) :: Q.t
  operate_on_two_args(:replace, 55)

  @doc """
  Delete one or more documents from a table.

  The optional arguments are:

  * durability: possible values are hard and soft. This option will override the 
    table or query’s durability setting (set in run).
    In soft durability mode RethinkDB will acknowledge the write immediately after 
    receiving it, but before the write has been committed to disk.
  * return_changes: if set to True, return a changes array consisting of 
    old_val/new_val objects describing the changes made.

  Delete returns an object that contains the following attributes:

  * deleted: the number of documents that were deleted.
  * skipped: the number of documents that were skipped.
    For example, if you attempt to delete a batch of documents, and another 
    concurrent query deletes some of those documents first, they will be counted as 
    skipped.
  * errors: the number of errors encountered while performing the delete.
  * first_error: If errors were encountered, contains the text of the first error.
    inserted, replaced, and unchanged: all 0 for a delete operation.
  * changes: if return_changes is set to True, this will be an array of objects, 
    one for each objected affected by the delete operation. Each object will have 
  * two keys: {"new_val": None, "old_val": <old value>}.
  """
  @spec delete(Q.t) :: Q.t
  operate_on_single_arg(:delete, 54)

  @doc """
  sync ensures that writes on a given table are written to permanent storage. 
  Queries that specify soft durability (durability='soft') do not give such 
  guarantees, so sync can be used to ensure the state of these queries. A call to 
  sync does not return until all previous writes to the table are persisted.

  If successful, the operation returns an object: {"synced": 1}.

  """
  @spec sync(Q.t) :: Q.t
  operate_on_single_arg(:sync, 138)

end
