defmodule ChangesTest do
  use ExUnit.Case, async: false
  alias RethinkDB.Feed
  use RethinkDB.Connection
  import RethinkDB.Query

  @table_name "changes_test_table_1"

  setup_all do
    start_link()

    db_create("test") |> run
    table_create(@table_name) |> run

    on_exit fn ->
      start_link()

      db_drop("test") |> run
    end
    :ok
  end

  setup do
    table(@table_name) |> delete |> run
    :ok
  end

  test "first change" do
    q = table(@table_name) |> changes
    {:ok, changes = %Feed{}} = run(q)

    t = Task.async fn ->
      changes |> Enum.take(1)
    end
    data = %{"test" => "d"}
    table(@table_name) |> insert(data) |> run
    [h|[]] = Task.await(t)
    assert %{"new_val" => %{"test" => "d"}} = h
  end

  test "changes" do
    q = table(@table_name) |> changes
    {:ok, changes} = {:ok, %Feed{}} = run(q)
    t = Task.async fn ->
      RethinkDB.Connection.next(changes)
    end
    data = %{"test" => "data"}
    q = table(@table_name) |> insert(data)
    {:ok, res} = run(q)
    expected = res.data["id"]
    {:ok, changes} = Task.await(t)
    ^expected = changes.data |> hd |> Map.get("id")

    # test Enumerable
    t = Task.async fn ->
      changes |> Enum.take(5)
    end
    1..6 |> Enum.each(fn _ ->
      q = table(@table_name) |> insert(data)
      run(q)
    end)
    data = Task.await(t)
    5 = Enum.count(data)
  end

  test "point_changes" do
    q = table(@table_name) |> get("0") |> changes
    {:ok, changes} = {:ok, %Feed{}} = run(q)
    t = Task.async fn ->
      changes |> Enum.take(1)
    end
    data = %{"id" => "0"}
    q = table(@table_name) |> insert(data)
    {:ok, res} = run(q)

    # Unused?
    _expected = res.data["id"]

    [h|[]] = Task.await(t)
    assert %{"new_val" => %{"id" => "0"}} = h
  end

  test "changes opts binary native" do
    q = table(@table_name) |> get("0") |> changes
    {:ok, changes} = {:ok, %Feed{}} = run(q)
    t = Task.async fn ->
      changes |> Enum.take(1)
    end
    data = %{"id" => "0", "binary" => binary(<<1>>)}
    q = table(@table_name) |> insert(data)
    {:ok, res} = run(q)
    expected = res.data["id"]
    [h|[]] = Task.await(t)
    assert %{"new_val" => %{"id" => "0", "binary" => <<1>>}} = h
  end

  test "changes opts binary raw" do
    q = table(@table_name) |> get("0") |> changes
    {:ok, changes} = {:ok, %Feed{}} = run(q, [binary_format: :raw])
    t = Task.async fn ->
      changes |> Enum.take(1)
    end
    data = %{"id" => "0", "binary" => binary(<<1>>)}
    q = table(@table_name) |> insert(data)
    {:ok, res} = run(q)
    expected = res.data["id"]
    [h|[]] = Task.await(t)
    assert %{"new_val" => %{"id" => "0", "binary" => %RethinkDB.Pseudotypes.Binary{data: "AQ=="}}} = h
  end
end
