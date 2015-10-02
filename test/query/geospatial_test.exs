defmodule GeospatialTest do
  use ExUnit.Case
  use TestConnection

  alias RethinkDB.Record
  alias RethinkDB.Collection
  alias RethinkDB.Pseudotypes.Geometry.Point
  alias RethinkDB.Pseudotypes.Geometry.Line
  alias RethinkDB.Pseudotypes.Geometry.Polygon

  setup_all do
    connect
    :ok
  end

  @db_name "query_test_db_1"
  @table_name "query_test_table_1"

  setup do
    q = db_drop(@db_name)
    run(q)

    q = table_drop(@table_name)
    run(q)
    :ok
  end

  test "circle" do
    %Record{data: data} = circle({1,1}, 5) |> run
    assert %Polygon{outer_coordinates: [_h | _t], inner_coordinates: []} = data
  end

  test "distance" do
    %Record{data: data} = distance(point({1,1}), point({2,2})) |> run
    assert data == 156876.14940188665
  end
 
  test "fill" do
    %Record{data: data} = fill(line([{1,1}, {4,5}, {2,2}, {1,1}])) |> run
    assert data == %Polygon{outer_coordinates: [{1,1}, {4,5}, {2,2}, {1,1}]}
  end

  test "geojson" do
    %Record{data: data} = geojson(%{coordinates: [1,1], type: "Point"}) |> run
    assert data == %Point{coordinates: {1,1}}
  end

  test "to_geojson" do
    %Record{data: data} = point({1,1}) |> to_geojson |> run
    assert data == %{"type" => "Point", "coordinates" => [1,1]}
  end

  # TODO: get_intersecting, get_nearest, includes, intersects
  test "point" do
    %Record{data: data} = point({1,1}) |> run
    assert data == %Point{coordinates: {1, 1}}
  end

  test "line" do
    %Record{data: data} = line([{1,1}, {4,5}]) |> run
    assert data == %Line{coordinates: [{1, 1}, {4,5}]}
  end

  test "get_intersecting" do
    table_create(@table_name) |> run
    table(@table_name) |> index_create("location", %{geo: true}) |> run
    table(@table_name) |> index_wait(["location"]) |> run
    table(@table_name) |> insert(
      %{location: point(0.001,0.001)}
    ) |> run
    table(@table_name) |> insert(
      %{location: point(0.001,0)}
    ) |> run
    %Collection{data: data} = table(@table_name) |> get_intersecting(
      circle({0,0}, 5000),
      %{index: "location"}
    ) |> run
    points = for x <- data, do: x["location"].coordinates
    assert Enum.sort(points) == [{0.001, 0}, {0.001,0.001}]
  end

  test "get_nearest" do
    table_create(@table_name) |> run
    table(@table_name) |> index_create("location", %{geo: true}) |> run
    table(@table_name) |> index_wait(["location"]) |> run
    table(@table_name) |> insert(
      %{location: point(0.001,0.001)}
    ) |> run
    table(@table_name) |> insert(
      %{location: point(0.001,0)}
    ) |> run
    %Record{data: data} = table(@table_name) |> get_nearest(
      point({0,0}),
      %{index: "location", max_dist: 5000000}
    ) |> run
    assert Enum.count(data) == 2
  end

  test "includes" do
    %Record{data: data} = [circle({0,0}, 1000), circle({0.001,0}, 1000), circle({100,100}, 1)] |> includes(
        point(0,0)
      ) |> run
    assert Enum.count(data) == 2
    %Record{data: data} = circle({0,0}, 1000) |> includes(point(0,0)) |> run
    assert data == true
    %Record{data: data} = circle({0,0}, 1000) |> includes(point(80,80)) |> run
    assert data == false
  end

  test "intersects" do
    b = [
        circle({0,0}, 1000), circle({0,0}, 1000), circle({80,80}, 1)
      ] |> intersects(
        circle({0,0}, 10)
      )
    %Record{data: data} = b |> run
    assert Enum.count(data) == 2
    %Record{data: data} = circle({0,0}, 1000) |> intersects(circle({0,0}, 1)) |> run
    assert data == true
    %Record{data: data} = circle({0,0}, 1000) |> intersects(circle({80,80}, 1)) |> run
    assert data == false
  end

  test "polygon" do
    %Record{data: data} = polygon([{0,0}, {0,1}, {1,1}, {1,0}]) |> run
    assert data.outer_coordinates == [{0,0}, {0,1}, {1,1}, {1,0}, {0,0}]
  end

  test "polygon_sub" do
    p1 = polygon([{0,0}, {0,1}, {1,1}, {1,0}])
    p2 = polygon([{0.25,0.25}, {0.25,0.5}, {0.5,0.5}, {0.5,0.25}])
    %Record{data: data} = p1 |> polygon_sub(p2) |> run
    assert data.outer_coordinates == [{0,0}, {0,1}, {1,1}, {1,0}, {0,0}]
    assert data.inner_coordinates == [{0.25,0.25}, {0.25,0.5}, {0.5,0.5}, {0.5,0.25}, {0.25,0.25}]
  end
end
