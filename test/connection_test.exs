defmodule ConnectionTest do
  use ExUnit.Case, async: true
  import Supervisor.Spec
  use RethinkDB.Connection
  import RethinkDB.Query

  test "Connections can be supervised" do
    children = [worker(RethinkDB.Connection, [])]
    {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one)
    assert Supervisor.count_children(sup) == %{active: 1, specs: 1, supervisors: 0, workers: 1}
    Process.exit(sup, :normal)
  end

  test "using Connection works with supervision" do
    children = [worker(__MODULE__, [])]
    {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one)
    assert Supervisor.count_children(sup) == %{active: 1, specs: 1, supervisors: 0, workers: 1}
    Process.exit(sup, :normal)
  end

  test "reconnects if initial connect fails" do
    connect([port: 28014])
    %RethinkDB.Exception.ConnectionClosed{} = table_list |> run
    conn = FlakyConnection.start('localhost', 28015, 28014)
    :timer.sleep(1000)
    %RethinkDB.Record{} = RethinkDB.Query.table_list |> run
    FlakyConnection.stop(conn)
  end

  require Logger

  test "replies to pending queries on disconnect" do
    conn = FlakyConnection.start('localhost', 28015)
    connect([port: conn.port])
    table = "foo_flaky_test"
    RethinkDB.Query.table_create(table)|> run
    on_exit fn ->
      connect
      RethinkDB.Query.table_drop(table) |> run
      GenServer.cast(__MODULE__, :stop)
    end
    table(table) |> index_wait |> run
    change_feed = table(table) |> changes |> run
    task = Task.async fn ->
      next change_feed
    end
    :timer.sleep(100)
    FlakyConnection.stop(conn)
    %RethinkDB.Exception.ConnectionClosed{} = Task.await(task)
  end

  test "supervised connection restarts on disconnect" do
    conn = FlakyConnection.start('localhost', 28015)
    children = [worker(__MODULE__, [[port: conn.port]])]
    {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one)
    assert Supervisor.count_children(sup) == %{active: 1, specs: 1, supervisors: 0, workers: 1}

    FlakyConnection.stop(conn)
    :timer.sleep(100) # this is a band-aid for a race condition in this test
   
    assert Supervisor.count_children(sup) == %{active: 1, specs: 1, supervisors: 0, workers: 1}

    Process.exit(sup, :normal)
  end
end
