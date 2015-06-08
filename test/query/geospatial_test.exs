defmodule GeospatialTest do
  use ExUnit.Case
  use TestConnection

  alias RethinkDB.Record
  alias RethinkDB.Pseudotypes.Geometry.Point
  alias RethinkDB.Pseudotypes.Geometry.Line
  alias RethinkDB.Pseudotypes.Geometry.Polygon

  setup_all do
    connect
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

  test "point" do
    %Record{data: data} = point({1,1}) |> run
    assert data == %Point{coordinates: {1, 1}}
  end

  test "line" do
    %Record{data: data} = line([{1,1}, {4,5}]) |> run
    assert data == %Line{coordinates: [{1, 1}, {4,5}]}
  end
end
