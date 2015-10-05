defmodule WritingDataTestDB, do: use RethinkDB.Connection
defmodule WritingDataTest do
  use ExUnit.Case, async: true
  use WritingDataTestDB
  alias RethinkDB.Record
  alias RethinkDB.Collection

  setup_all do
    connect
    :ok
  end

  @table_name "writing_data_test_table_1"
  setup do
    q = table_drop(@table_name)
    run(q)
    q = table_create(@table_name)
    run(q)
    on_exit fn ->
      q = table_drop(@table_name)
      run(q)
    end
    :ok
  end

  test "insert" do
    table_query = table(@table_name)
    q = insert(table_query, %{name: "Hello", attr: "World"})
    %Record{data: %{"inserted" => 1, "generated_keys" => [key]}} = run(q)

    %Collection{data: [%{"id" => ^key, "name" => "Hello", "attr" => "World"}]} = run(table_query)
  end

  test "insert multiple" do
    table_query = table(@table_name)

    q = insert(table_query, [%{name: "Hello"}, %{name: "World"}])
    %Record{data: %{"inserted" => 2}} = run(q)

    %Collection{data: data} = run(table_query)
    assert Enum.map(data, &(&1["name"])) |> Enum.sort == ["Hello", "World"]
  end

  test "update" do
    table_query = table(@table_name)
    q = insert(table_query, %{name: "Hello", attr: "World"})
    %Record{data: %{"inserted" => 1, "generated_keys" => [key]}} = run(q)

    record_query = table_query |> get(key)
    q = record_query |> update(%{name: "Hi"})
    run q
    q = record_query
    %Record{data: data} = run q
    assert data == %{"id" => key, "name" => "Hi", "attr" => "World"}
  end

  test "replace" do
    table_query = table(@table_name)
    q = insert(table_query, %{name: "Hello", attr: "World"})
    %Record{data: %{"inserted" => 1, "generated_keys" => [key]}} = run(q)

    record_query = table_query |> get(key)
    q = record_query |> replace(%{id: key, name: "Hi"})
    run q
    q = record_query
    %Record{data: data} = run q
    assert data == %{"id" => key, "name" => "Hi"}
  end

  test "sync" do
    table_query = table(@table_name)
    q = table_query |> sync
    %Record{data: data} = run q
    assert data == %{"synced" => 1}
  end

end
