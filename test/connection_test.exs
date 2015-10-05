defmodule ConnectionTestDB, do: use RethinkDB.Connection
defmodule ConnectionTest do
  use ExUnit.Case, async: true
  import Supervisor.Spec

  test "Connections can be supervised" do
    children = [worker(RethinkDB.Connection, [])]
    {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one)
    assert Supervisor.count_children(sup) == %{active: 1, specs: 1, supervisors: 0, workers: 1}
    Process.exit(sup, :normal)
  end

  test "using Connection works with supervision" do
    children = [worker(ConnectionTestDB, [])]
    {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one)
    assert Supervisor.count_children(sup) == %{active: 1, specs: 1, supervisors: 0, workers: 1}
    Process.exit(sup, :normal)
  end

  test "reconnects if initial connect fails" do
    ConnectionTestDB.connect([port: 28014])
    %RethinkDB.Exception.ConnectionClosed{} = RethinkDB.Query.table_list |> ConnectionTestDB.run
    conn = FlakyConnection.start('localhost', 28015, 28014)
    :timer.sleep(1000)
    %RethinkDB.Record{} = RethinkDB.Query.table_list |> ConnectionTestDB.run
    FlakyConnection.stop(conn)
  end

  test "replies to pending queries on disconnect" do
    conn = FlakyConnection.start('localhost', 28015)
    ConnectionTestDB.connect([port: conn.port])
    RethinkDB.Query.table_create("foo_flaky_test") |> ConnectionTestDB.run
    %RethinkDB.Record{data: [table | _]} = RethinkDB.Query.table_list |> ConnectionTestDB.run
    change_feed = RethinkDB.Query.table(table) |> RethinkDB.Query.changes |> ConnectionTestDB.run
    task = Task.async fn ->
      ConnectionTestDB.next change_feed
    end
    :timer.sleep(100)
    FlakyConnection.stop(conn)
    %RethinkDB.Exception.ConnectionClosed{} = Task.await(task)
  end

  test "supervised connection restarts on disconnect" do
    conn = FlakyConnection.start('localhost', 28015)
    children = [worker(ConnectionTestDB, [[port: conn.port]])]
    {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one)
    assert Supervisor.count_children(sup) == %{active: 1, specs: 1, supervisors: 0, workers: 1}

    FlakyConnection.stop(conn)
    :timer.sleep(100) # this is a band-aid for a race condition in this test
   
    assert Supervisor.count_children(sup) == %{active: 1, specs: 1, supervisors: 0, workers: 1}

    Process.exit(sup, :normal)
  end
end
