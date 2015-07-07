defmodule ConnectionTest do
  use ExUnit.Case
  import Supervisor.Spec

  test "Connections can be supervised" do
    children = [worker(RethinkDB.Connection, [])]
    {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one)
    assert Supervisor.count_children(sup) == %{active: 1, specs: 1, supervisors: 0, workers: 1}
  end

  test "using Connection works with supervision" do
    children = [worker(TestConnection, [])]
    {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one)
    assert Supervisor.count_children(sup) == %{active: 1, specs: 1, supervisors: 0, workers: 1}
  end
end
