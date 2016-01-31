defmodule ChangesTest do
  use ExUnit.Case, async: true
  alias RethinkDB.Feed
  use RethinkDB.Connection
  import RethinkDB.Query

  @table_name "changes_test_table_1"
  setup_all do
    start_link
    table_create(@table_name) |> run
    on_exit fn ->
      start_link
      table_drop(@table_name) |> run
    end
    :ok
  end

  setup do
    table(@table_name) |> delete |> run
    :ok
  end

  test "first change" do
    q = table(@table_name) |> changes
    changes = %Feed{} = run(q)

    t = Task.async fn ->
      changes |> Enum.take(1)
    end
    data = %{"test" => "d"}
    table(@table_name) |> insert(data) |> run
    [h|[]] = Task.await(t)
    assert %{"new_val" => %{"test" => "d"}} = h
  end

  test "changes" do
    q = table(@table_name) |> changes
    changes = %Feed{} = run(q)
    t = Task.async fn ->
      RethinkDB.Connection.next(changes)
    end
    data = %{"test" => "data"}
    q = table(@table_name) |> insert(data)
    res = run(q)
    expected = res.data["id"]
    changes = Task.await(t) 
    ^expected = changes.data |> hd |> Map.get("id")

    # test Enumerable
    t = Task.async fn ->
      changes |> Enum.take(5)  
    end
    1..6 |> Enum.each(fn _ ->
      q = table(@table_name) |> insert(data)
      run(q)
    end)
    data = Task.await(t) 
    5 = Enum.count(data)
  end

  #test supervisable changefeed
  defmodule TestChangefeed do
    use RethinkDB.Changefeed

    require Logger

    def init({q, pid}) do
      {:subscribe, q, ChangesTest, {:setup, pid}}
    end
    def init({q, pid, db}) do
      {:subscribe, q, db, {:setup, pid}}
    end

    def handle_update(foo, {:setup, pid}) do
      send pid, {:ready, foo}
      {:next, pid}
    end

    def handle_update(foo, pid) do
      send pid, {:update, foo}
      {:next, pid}
    end

    def handle_call(:ping, _from, pid) do
      {:reply, {:pong, pid}, pid}
    end

    def handle_cast({:ping, p}, state) do
      send p, :pong
      {:noreply, state}
    end

    def handle_info({:ping, p}, state) do
      send p, :pong
      {:noreply, state}
    end

    def handle_info(:stop, state) do
      {:stop, :normal, state}
    end

    def terminate(_, pid) do
      send pid, :terminated
    end

    def code_change(_, pid, _) do
      send pid, :change
      {:ok, pid}
    end
  end

  test "changefeed process" do
    q = table(@table_name) |> changes
    {:ok, _} = RethinkDB.Changefeed.start_link(
      TestChangefeed,
      {q, self},
      [])
    receive do
      {:ready, _} -> :ok
    end
    table(@table_name) |> insert(%{something: :blue}) |> run
    receive do
      {:update, [%{"new_val" => %{"something" => val}}]} ->
        assert val == "blue"
    end
  end

  test "single document changefeed" do
    %RethinkDB.Record{data: %{"generated_keys" => [id]}} = table(@table_name)
                          |> insert(%{"test" => "value"}) |> run
    q = table(@table_name) |> get(id) |> changes(include_initial: true)
    {:ok, _} = RethinkDB.Changefeed.start_link(
      TestChangefeed,
      {q,self},
      [])
    receive do
      {:ready, data} ->
        assert data["new_val"]["test"] == "value"
    end
    table(@table_name) |> get(id) |> update(%{"test" => "new_value"}) |> run
    receive do
      {:update, data} ->
        assert data["new_val"]["test"] == "new_value"
    end
  end

  test "broken connection changefeed" do
    f_conn = FlakyConnection.start('localhost', 28015)
    port = f_conn.port
    {:ok, c} = RethinkDB.Connection.start_link([port: port])
    q = table(@table_name) |> changes
    {:ok, pid} = RethinkDB.Changefeed.start_link(
      TestChangefeed,
      {q,self,c},
      [])
    receive do
      {:ready, _} -> :ok
    end
    ref = Process.monitor(pid)
    Process.unlink(pid)
    Process.unlink(c)
    FlakyConnection.stop(f_conn)
    receive do
      {:DOWN, ^ref, :process, ^pid, _} -> :ok
    after
      20 -> throw "Expected changefeed to stop on disconnect"
    end
  end

  test "retry connection changefeed" do
    port = 28000
    {:ok, c} = RethinkDB.Connection.start_link(port: port)
    q = table(@table_name) |> changes
    {:ok, _} = RethinkDB.Changefeed.start_link(
      TestChangefeed,
      {q,self,c},
      [])
    FlakyConnection.start('localhost', 28015, [local_port: port])
    receive do
      {:ready, _} -> :ok
    end
  end

  test "GenServer Call" do
    q = table(@table_name) |> changes
    {:ok, pid} = RethinkDB.Changefeed.start_link(
      TestChangefeed,
      {q, self},
      [])
    receive do
      {:ready, _} -> :ok
    end
    assert RethinkDB.Changefeed.call(pid, :ping) == {:pong, self}
  end

  test "GenServer Cast" do
    q = table(@table_name) |> changes
    {:ok, pid} = RethinkDB.Changefeed.start_link(
      TestChangefeed,
      {q, self},
      [])
    receive do
      {:ready, _} -> :ok
    end
    RethinkDB.Changefeed.cast(pid, {:ping, self})
    receive do
      :pong -> :ok
    after
      10 -> throw "should have received response"
    end
  end

  test "GenServer Info" do
    q = table(@table_name) |> changes
    {:ok, pid} = RethinkDB.Changefeed.start_link(
      TestChangefeed,
      {q, self},
      [])
    receive do
      {:ready, _} -> :ok
    end
    send pid, {:ping, self}
    receive do
      :pong -> :ok
    after
      10 -> throw "should have received response"
    end
  end

  test "GenServer code change" do
    q = table(@table_name) |> changes
    {:ok, pid} = RethinkDB.Changefeed.start_link(
      TestChangefeed,
      {q, self},
      [])
    receive do
      {:ready, _} -> :ok
    end
    :sys.suspend(pid)
    :sys.change_code(pid, TestChangefeed, make_ref, nil)
    :sys.resume(pid)
    receive do
      :change -> :ok
    after
      10 -> throw "should have received changes"
    end
  end

  test "GenServer terminate" do
    q = table(@table_name) |> changes
    {:ok, pid} = RethinkDB.Changefeed.start_link(
      TestChangefeed,
      {q, self},
      [])
    receive do
      {:ready, _} -> :ok
    end
    send pid, :stop
    receive do
      :terminated -> :ok
    after
      10 -> throw "should have received terminated"
    end
  end
end
