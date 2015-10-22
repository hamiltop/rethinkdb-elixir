defmodule RethinkDB.Connection do
  @moduledoc  """
  A module for managing connections.

  A `Connection` object is a process that can be started in various ways.

  It is recommended to start it as part of a supervision tree with a name:

      worker(RethinkDB.Connection, [[port: 28015, host: 'localhost', name: :rethinkdb_database]])

  Connections will by default connect asynchronously. If a connection fails, we retry with
  an exponential backoff. All queries will return `%RethinkDB.Exception.ConnectionClosed{}`
  until the connection is established.

  If `:sync_connect` is set to `true` then the process will crash if we fail to connect. It's
  recommended to only use this if the database is on the same host or if a rethinkdb proxy
  is running on the same host. If there's any chance of a network partition, it's recommended
  to stick with the default behavior.
  """
  use Connection

  require Logger

  alias RethinkDB.Connection.Request

  @doc """
  A convenience macro for naming connections.

  For convenience we provide the `use RethinkDB.Connection` macro, which automatically registers
  itself under the module name:

      defmodule FooDatabase, do: use RethinkDB.Connection

  Then in the supervision tree:

      worker(FooDatabase, [[port: 28015, host: 'localhost']])

  When `use RethinkDB.Connection` is called, it will define:

  * `start_link`
  * `stop`
  * `run`

  All of these only differ from the normal `RethinkDB.Connection` functions in that they don't
  accept a connection. They will use the current module as the process name. `start_link` will
  start the connection under the module name.

  """
  defmacro __using__(_opts) do
    quote do
      def start_link(opts \\ []) do
        RethinkDB.Connection.start_link(Dict.put_new(opts, :name, __MODULE__))
      end

      def run(query, opts \\ []) do
        RethinkDB.Connection.run(query, __MODULE__, opts)
      end

      def stop do
        RethinkDB.Connection.stop(__MODULE__)
      end
    end
  end

  @doc """
  Stop the connection.

  Stops the given connection.
  """
  def stop(pid) do
    Connection.cast(pid, :stop)
  end

  @doc """
  Run a query on a connection.

  Supports the following options:

  * `timeout` - How long to wait for a response
  * `db` - Default database to use for query. Can also be specified as part of the query.
  """
  def run(query, conn, opts \\ []) do
    timeout = Dict.get(opts, :timeout, 5000)
    conn_opts = Dict.take(opts, [:db])
    conn_opts = Connection.call(conn, :conn_opts)
      |> Dict.merge(conn_opts)
    query = prepare_and_encode(query, conn_opts)
    case Connection.call(conn, {:query, query}, timeout) do
      {response, token} -> RethinkDB.Response.parse(response, token, conn)
      result -> result
    end
  end

  @doc """
  Fetch the next dataset for a feed.

  Since a feed is tied to a particular connection, no connection is needed when calling
  `next`.
  """
  def next(%{token: token, pid: pid}) do
    case Connection.call(pid, {:continue, token}, :infinity) do
      {response, token} -> RethinkDB.Response.parse(response, token, pid)
      x -> x
    end
  end
  
  @doc """
  Closes a feed.

  Since a feed is tied to a particular connection, no connection is needed when calling
  `close`.
  """
  def close(%{token: token, pid: pid}) do
    {response, token} = Connection.call(pid, {:stop, token}, :infinity)
    RethinkDB.Response.parse(response, token, pid)
  end

  defp prepare_and_encode(query, opts) do
    query = RethinkDB.Prepare.prepare(query)
    query = [1, query]
    query = case opts do
      %{db: nil} -> query
      %{db: db} ->
        db_query = RethinkDB.Prepare.prepare(RethinkDB.Query.db(db))
        query ++ [%{db: db_query}]
      _ -> query
    end
    Poison.encode!(query)
  end

  @doc """
  Start connection as a linked process

  Accepts a `Dict` of options. Supported options:

  * `:host` - hostname to use to connect to database. Defaults to `'localhost'`.
  * `:port` - port on which to connect to database. Defaults to `28015`.
  * `:auth_key` - authorization key to use with database. Defaults to `nil`.
  * `:db` - default database to use with queries. Defaults to `nil`.
  * `:sync_connect` - whether to have `init` block until a connection succeeds. Defaults to `false`.
  """
  def start_link(opts \\ []) do
    args = Dict.take(opts, [:host, :port, :auth_key, :db, :sync_connect])
    Connection.start_link(__MODULE__, args, opts)
  end

  def init(opts) do
    host = case Dict.get(opts, :host, 'localhost') do
      x when is_binary(x) -> String.to_char_list x
      x -> x
    end
    port = Dict.get(opts, :port, 28015)
    auth_key = Dict.get(opts, :auth_key, "")
    db = Dict.get(opts, :db)
    sync_connect = Dict.get(opts, :sync_connect, false)
    state = %{
      pending: %{},
      current: {:start, ""},
      token: 0,
      config: %{port: port, host: host, auth_key: auth_key, db: db}
    }
    case sync_connect do
      true -> 
        case connect(:sync, state) do
          {:backoff, _, _} -> {:stop, :econnrefused}
          x -> x
        end
      false ->
        {:connect, :init, state}
    end
  end

  def connect(_info, state = %{config: %{host: host, port: port, auth_key: auth_key}}) do
    case :gen_tcp.connect(host, port, [active: false, mode: :binary]) do
      {:ok, socket} ->
        case handshake(socket, auth_key) do
          {:error, _} -> {:stop, :bad_handshake, state}
          :ok ->
            :ok = :inet.setopts(socket, [active: :once])
            # TODO: investigate timeout vs hibernate
            {:ok, Dict.put(state, :socket, socket)}
        end
      {:error, :econnrefused} ->
        backoff = min(Dict.get(state, :timeout, 1000), 64000)
        {:backoff, backoff, Dict.put(state, :timeout, backoff*2)}
    end
  end

  def disconnect(info, state = %{pending: pending}) do
    pending |> Enum.each(fn {_token, pid} ->
      Connection.reply(pid, %RethinkDB.Exception.ConnectionClosed{})
    end)
    new_state = state
      |> Map.delete(:socket)
      |> Map.put(:pending, %{})
      |> Map.put(:current, {:start, ""})
    # TODO: should we reconnect?
    {:stop, info, new_state}
  end

  def handle_call({:query, query}, from, state = %{token: token}) do
    new_token = token + 1
    token = << token :: little-size(64) >>
    Request.make_request(query, token, from, %{state | token: new_token})
  end

  def handle_call({:continue, token}, from, state) do
    query = "[2]"
    Request.make_request(query, token, from, state)
  end

  def handle_call({:stop, token}, from, state) do
    query = "[3]"
    Request.make_request(query, token, from, state)
  end

  def handle_call(:conn_opts, _from, state = %{config: opts}) do
    {:reply, opts, state}
  end

  def handle_cast(:stop, state) do
    {:disconnect, :normal, state};
  end

  def handle_info({:tcp, _port, data}, state = %{socket: socket}) do
    :ok = :inet.setopts(socket, [active: :once])
    Request.handle_recv(data, state)
  end

  def handle_info({:tcp_closed, _port}, state) do
    {:disconnect, :tcp_closed, state}
  end

  def handle_info(msg, state) do
    Logger.debug("Received unhandled info: #{inspect(msg)} with state #{inspect state}")
    {:noreply, state}
  end

  def terminate(_reason, %{socket: socket}) do
    :gen_tcp.close(socket)
    :ok
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp handshake(socket, auth_key) do
    :ok = :gen_tcp.send(socket, << 0x400c2d20 :: little-size(32) >>)
    :ok = :gen_tcp.send(socket, << :erlang.iolist_size(auth_key) :: little-size(32) >>)
    :ok = :gen_tcp.send(socket, auth_key)
    :ok = :gen_tcp.send(socket, << 0x7e6970c7 :: little-size(32) >>)
    case recv_until_null(socket, "") do
      "SUCCESS" -> :ok
      error = {:error, _} -> error
    end
  end

  defp recv_until_null(socket, acc) do
    case :gen_tcp.recv(socket, 1) do
      {:ok, "\0"} -> acc
      {:ok, a}    -> recv_until_null(socket, acc <> a)
      x = {:error, _} -> x
    end
  end
end
