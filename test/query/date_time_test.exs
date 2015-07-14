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

  test "epoch_time" do
    %Record{data: data} = epoch_time(1) |> run
    assert data.epoch_time == 1
    assert data.timezone == "+00:00"
  end

  test "iso8601" do
    %Record{data: data} = iso8601("1970-01-01T00:00:00+00:00") |> run
    assert data.epoch_time == 0
    assert data.timezone == "+00:00"
    %Record{data: data} = iso8601("1970-01-01T00:00:00", %{"default_timezone" => "+01:00"}) |> run
    assert data.epoch_time == -3600
    assert data.timezone == "+01:00"
  end

  test "in_timezone" do
    %Record{data: data} = epoch_time(0) |> in_timezone("+01:00") |> run
    assert data.timezone == "+01:00"
    assert data.epoch_time == 0
  end

  test "timezone" do
    %Record{data: data} = %Time{epoch_time: 0, timezone: "+01:00"} |> timezone |> run
    assert data == "+01:00"
  end

  test "during" do
    a = epoch_time(5)
    b = epoch_time(10)
    c = epoch_time(7)
    %Record{data: data} = c |> during(a,b) |> run
    assert data == true
    %Record{data: data} = b |> during(a,c) |> run
    assert data == false
  end
end
