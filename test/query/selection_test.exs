defmodule SelectionTest do
  use ExUnit.Case
  use TestConnection

  setup_all do
    TestConnection.connect
    :ok
  end

  @db_name "query_test_db_1"
  @table_name "query_test_table_1"
  setup context do
    q = db_drop(@db_name)
    run(q)

    q = table_drop(@table_name)
    run(q)
    {:ok, context}
  end
end
