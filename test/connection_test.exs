defmodule ConnectionTest do
  use ExUnit.Case, async: true
  import Supervisor.Spec
  use RethinkDB.Connection
  import RethinkDB.Query

  require Logger

  test "Connections can be supervised" do
    children = [worker(RethinkDB.Connection, [])]
    {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one)
    assert Supervisor.count_children(sup) == %{active: 1, specs: 1, supervisors: 0, workers: 1}
    Process.exit(sup, :kill)
  end

  test "using Connection works with supervision" do
    children = [worker(__MODULE__, [])]
    {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one)
    assert Supervisor.count_children(sup) == %{active: 1, specs: 1, supervisors: 0, workers: 1}
    Process.exit(sup, :kill)
  end

  test "using Connection will raise if name is provided" do
    assert_raise ArgumentError, fn ->
      start_link(name: :test)
    end
  end

  test "reconnects if initial connect fails" do
    {:ok, c} = start_link(port: 28014)
    Process.unlink(c)
    %RethinkDB.Exception.ConnectionClosed{} = table_list() |> run
    conn = FlakyConnection.start('localhost', 28015, [local_port: 28014])
    :timer.sleep(1000)
    {:ok, %RethinkDB.Record{}} = RethinkDB.Query.table_list() |> run
    ref = Process.monitor(c)
    FlakyConnection.stop(conn)
    receive do
      {:DOWN, ^ref, _, _, _} -> :ok
    end
  end

  test "replies to pending queries on disconnect" do
    conn = FlakyConnection.start('localhost', 28015)
    {:ok, c} = start_link(port: conn.port)
    Process.unlink(c)
    table = "foo_flaky_test"
    RethinkDB.Query.table_create(table)|> run
    on_exit fn ->
      start_link()
      :timer.sleep(100)
      RethinkDB.Query.table_drop(table) |> run
      GenServer.cast(__MODULE__, :stop)
    end
    table(table) |> index_wait |> run
    {:ok, change_feed} = table(table) |> changes |> run
    task = Task.async fn ->
      RethinkDB.Connection.next change_feed
    end
    :timer.sleep(100)
    ref = Process.monitor(c)
    FlakyConnection.stop(conn)
    %RethinkDB.Exception.ConnectionClosed{} = Task.await(task)
    receive do
      {:DOWN, ^ref, _, _, _} -> :ok
    end
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

  test "connection accepts default db" do
    {:ok, c} = RethinkDB.Connection.start_link(db: "new_test")
    db_create("new_test") |> RethinkDB.run(c)
    db("new_test") |> table_create("new_test_table") |> RethinkDB.run(c)
    {:ok, %{data: data}} = table_list() |> RethinkDB.run(c)
    assert data == ["new_test_table"]
  end

  test "connection accepts max_pending" do
    {:ok, c} = RethinkDB.Connection.start_link(max_pending: 1)
    res = Enum.map(1..100, fn (_) ->
      Task.async fn ->
        now() |> RethinkDB.run(c)
      end
    end) |> Enum.map(&Task.await/1)
    assert Enum.any?(res, &(&1 == %RethinkDB.Exception.TooManyRequests{}))
  end

  test "sync connection" do
    {:error, :econnrefused} = Connection.start(RethinkDB.Connection, [port: 28014, sync_connect: true])
    conn = FlakyConnection.start('localhost', 28015, [local_port: 28014])
    {:ok, pid} = Connection.start(RethinkDB.Connection, [port: 28014, sync_connect: true])
    FlakyConnection.stop(conn)
    Process.exit(pid, :shutdown)
  end

  test "ssl connection" do
    conn = FlakyConnection.start('localhost', 28015, [ssl: [keyfile: "./test/cert/host.key", certfile: "./test/cert/host.crt"]])
    {:ok, c} = RethinkDB.Connection.start_link(port: conn.port, ssl: [ca_certs: ["./test/cert/rootCA.pem"]], sync_connect: true)
    {:ok, %{data: _}} = table_list() |> RethinkDB.run(c)
  end
end

defmodule ConnectionRunTest do
  use ExUnit.Case, async: true
  use RethinkDB.Connection
  import RethinkDB.Query

  setup_all do
    start_link()
    :ok
  end

  test "run(conn, opts) with :db option" do
    db_create("db_option_test") |> run
    table_create("db_option_test_table") |> run(db: "db_option_test")

    {:ok, %{data: data}} = db("db_option_test") |> table_list() |> run

    db_drop("db_option_test") |> run

    assert data == ["db_option_test_table"]
  end

  test "run(conn, opts) with :durability option" do
    table_drop("durability_test_table") |> run
    {:ok, response} = table_create("durability_test_table") |> run(durability: "soft")
    durability = response.data["config_changes"]
                 |> List.first
                 |> Map.fetch!("new_val")
                 |> Map.fetch!("durability")

    table_drop("durability_test_table") |> run

    assert durability == "soft"
  end

  test "run with :noreply option" do
    :ok = make_array([1,2,3]) |> run(noreply: true)
    noreply_wait()
  end

  test "run with :profile options" do
    {:ok, resp} = make_array([1,2,3]) |> run(profile: true)
    assert [%{"description" => _, "duration(ms)" => _,
             "sub_tasks" => _}] = resp.profile
  end
end
