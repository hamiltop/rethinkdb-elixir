ExUnit.start()
defmodule TestConnection do
  use Exrethinkdb.Connection

  def test_db_name, do: "query_test_db_1"
  def test_table_name, do: "query_test_table_1"

  defmacro with_test_db(block) do
    quote do
      try do
        db_create(test_db_name) |> run
        unquote(block)
      after
        db_drop(test_db_name) |> run
      end
    end
  end
end
