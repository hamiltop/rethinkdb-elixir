defmodule GeospatialTest do
  use ExUnit.Case
  use TestConnection
  alias RethinkDB.Query.Aggregation, as: A

  alias RethinkDB.Record

  setup_all do
    connect
    :ok
  end
  
  test "point" do
    %Record{data: data} = point {1,1} |> run
    assert data == "hi"
  end
end
