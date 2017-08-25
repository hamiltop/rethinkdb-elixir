defmodule PrepareTest do
  use ExUnit.Case, async: true
  import RethinkDB.Prepare

  test "single elements" do
    assert prepare(1) == 1
    assert prepare(make_ref()) == 1
  end

  test "list" do
    assert prepare([1,2,3]) == [1,2,3]
    assert prepare([1,2,make_ref(),make_ref()]) == [1,2,1,2]
  end

  test "nested list" do
    list = [1, [1,2], [1, [1, 2]]]
    assert prepare(list) == list
    list = [1, [make_ref(), make_ref()], make_ref(), [1, 2]]
    assert prepare(list) == [1, [1, 2], 3, [1, 2]]
  end

  test "map" do
    map = %{a: 1, b: 2}
    assert prepare(map) == map
    map = %{a: 1, b: make_ref(), c: make_ref()}
    assert prepare(map) == %{a: 1, b: 1, c: 2}
  end
end
