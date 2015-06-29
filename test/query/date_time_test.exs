defmodule DateTimeTest do
  use ExUnit.Case
  use TestConnection

  alias RethinkDB.Record
  alias RethinkDB.Pseudotypes.Time

  setup_all do
    connect
    :ok
  end

  test "now" do
    %Record{data: data} = now |> run
    assert %Time{} = data
  end

  test "time" do
    %Record{data: data} = time(1970,1,1,"Z") |> run
    assert data.epoch_time == 0
    %Record{data: data} = time(1970,1,1,0,0,1,"Z") |> run
    assert data.epoch_time == 1
  end
end
