defmodule GeospatialAdvTest do
  use ExUnit.Case, async: true
  use RethinkDB.Connection
  import RethinkDB.Query

  alias RethinkDB.Record

  @table_name "geo_test_table_1"
  setup_all do
    start_link()
    table_create(@table_name) |> run
    table(@table_name) |> index_create("location", geo: true) |> run
    table(@table_name) |> index_wait("location") |> run
    on_exit fn ->
      start_link()
      table_drop(@table_name) |> run
    end
    :ok
  end

  setup do
    table(@table_name) |> delete |> run
    :ok
  end

  test "get_intersecting" do
    table(@table_name) |> insert(
      %{location: point(0.001,0.001)}
    ) |> run
    table(@table_name) |> insert(
      %{location: point(0.001,0)}
    ) |> run
    {:ok, %{data: data}} = table(@table_name) |> get_intersecting(
      circle({0,0}, 5000), index: "location"
    ) |> run
    points = for x <- data, do: x["location"].coordinates
    assert Enum.sort(points) == [{0.001, 0}, {0.001,0.001}]
  end

  test "get_nearest" do
    table(@table_name) |> insert(
      %{location: point(0.001,0.001)}
    ) |> run
    table(@table_name) |> insert(
      %{location: point(0.001,0)}
    ) |> run
    {:ok, %Record{data: data}} = table(@table_name) |> get_nearest(
      point({0,0}), index: "location", max_dist: 5000000
    ) |> run
    assert Enum.count(data) == 2
  end
end
