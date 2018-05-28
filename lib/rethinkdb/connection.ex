defmodule RethinkDB.Connection do
  @moduledoc """
  A module for managing connections.

  A `Connection` object is a process that can be started in various ways.

  It is recommended to start it as part of a supervision tree with a name:

      worker(RethinkDB.Connection, [[port: 28015, host: 'localhost', name: :rethinkdb_connection]])

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
  alias RethinkDB.Connection.Transport

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

  If you attempt to provide a name to `start_link`, it will raise an `ArgumentError`.
  """
  defmacro __using__(_opts) do
    quote location: :keep do
      def start_link(opts \\ []) do
        if Keyword.has_key?(opts, :name) && opts[:name] != __MODULE__ do
          # The whole point of this macro is to provide an implicit process
          # name, so subverting it is considered an error.
          raise ArgumentError.exception(
                  "Process name #{inspect(opts[:name])} conflicts with implicit name #{
                    inspect(__MODULE__)
                  } provided by `use RethinkDB.Connection`"
                )
        end

        RethinkDB.Connection.start_link(Keyword.put_new(opts, :name, __MODULE__))
      end

      def run(query, opts \\ []) do
        RethinkDB.Connection.run(query, __MODULE__, opts)
      end

      def noreply_wait(timeout \\ 5000) do
        RethinkDB.Connection.noreply_wait(__MODULE__, timeout)
      end

      def stop do
        RethinkDB.Connection.stop(__MODULE__)
      end

      defoverridable start_link: 1, start_link: 0
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
  * `durability` - possible values are 'hard' and 'soft'. In soft durability mode RethinkDB will acknowledge the write immediately after receiving it, but before the write has been committed to disk.
  * `noreply` - set to true to not receive the result object or cursor and return immediately.
  * `profile` - whether or not to return a profile of the query’s execution (default: false).
  * `time_format` - what format to return times in (default: :native). Set this to :raw if you want times returned as JSON objects for exporting.
  * `binary_format` - what format to return binary data in (default: :native). Set this to :raw if you want the raw pseudotype.
  """
  def run(query, conn, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    conn_opts = Keyword.drop(opts, [:timeout])
    noreply = Keyword.get(opts, :noreply, false)

    conn_opts =
      Connection.call(conn, :conn_opts)
      |> Map.take([:db])
      |> Enum.to_list()
      |> Keyword.merge(conn_opts)

    query = prepare_and_encode(query, conn_opts)

    msg =
      case noreply do
        true -> {:query_noreply, query}
        false -> {:query, query}
      end

    case Connection.call(conn, msg, timeout) do
      {response, token} -> RethinkDB.Response.parse(response, token, conn, opts)
      :noreply -> :ok
      result -> result
    end
  end

  @doc """
  Fetch the next dataset for a feed.

  Since a feed is tied to a particular connection, no connection is needed when calling
  `next`.
  """
  def next(%{token: token, pid: pid, opts: opts}) do
    case Connection.call(pid, {:continue, token}, :infinity) do
      {response, token} -> RethinkDB.Response.parse(response, token, pid, opts)
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
    RethinkDB.Response.parse(response, token, pid, [])
  end

  @doc """
  `noreply_wait` ensures that previous queries with the noreply flag have been processed by the server. Note that this guarantee only applies to queries run on the given connection.
  """
  def noreply_wait(conn, timeout \\ 5000) do
    {response, token} = Connection.call(conn, :noreply_wait, timeout)

    case RethinkDB.Response.parse(response, token, conn, []) do
      {:ok, %RethinkDB.Response{data: %{"t" => 4}}} -> :ok
      r -> r
    end
  end

  defp prepare_and_encode(query, opts) do
    query = RethinkDB.Prepare.prepare(query)

    # Right now :db can still be nil so we need to remove it
    opts =
      Enum.into(opts, %{}, fn
        {:db, db} ->
          {:db, RethinkDB.Prepare.prepare(RethinkDB.Query.db(db))}

        {k, v} ->
          {k, v}
      end)

    query = [1, query, opts]
    Poison.encode!(query)
  end

  @doc """
  Start connection as a linked process

  Accepts a `Keyword` of options. Supported options:

  * `:host` - hostname to use to connect to database. Defaults to `'localhost'`.
  * `:port` - port on which to connect to database. Defaults to `28015`.
  * `:auth_key` - authorization key to use with database. Defaults to `nil`.
  * `:db` - default database to use with queries. Defaults to `nil`.
  * `:sync_connect` - whether to have `init` block until a connection succeeds. Defaults to `false`.
  * `:max_pending` - Hard cap on number of concurrent requests. Defaults to `10000`
  * `:ssl` - a dict of options. Support SSL options:
      * `:ca_certs` - a list of file paths to cacerts.
  """
  def start_link(opts \\ []) do
    args = Keyword.take(opts, [:host, :port, :auth_key, :db, :sync_connect, :ssl, :max_pending])
    Connection.start_link(__MODULE__, args, opts)
  end

  def init(opts) do
    host =
      case Keyword.get(opts, :host, 'localhost') do
        x when is_binary(x) -> String.to_charlist(x)
        x -> x
      end

    sync_connect = Keyword.get(opts, :sync_connect, false)
    ssl = Keyword.get(opts, :ssl)

    opts =
      Keyword.put(opts, :host, host)
      |> Keyword.put_new(:port, 28015)
      |> Keyword.put_new(:auth_key, "")
      |> Keyword.put_new(:max_pending, 10000)
      |> Keyword.drop([:sync_connect])
      |> Enum.into(%{})

    {transport, transport_opts} =
      case ssl do
        nil ->
          {%Transport.TCP{}, []}

        x ->
          {%Transport.SSL{},
           Enum.map(Keyword.fetch!(x, :ca_certs), &{:cacertfile, &1}) ++ [verify: :verify_peer]}
      end

    state = %{
      pending: %{},
      current: {:start, ""},
      token: 0,
      config: Map.put(opts, :transport, {transport, transport_opts})
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

  def connect(
        _info,
        state = %{
          config: %{
            host: host,
            port: port,
            auth_key: auth_key,
            transport: {transport, transport_opts}
          }
        }
      ) do
    case Transport.connect(
           transport,
           host,
           port,
           [active: false, mode: :binary] ++ transport_opts
         ) do
      {:ok, socket} ->
        case handshake(socket, auth_key) do
          {:error, _} ->
            {:stop, :bad_handshake, state}

          :ok ->
            :ok = Transport.setopts(socket, active: :once)
            # TODO: investigate timeout vs hibernate
            {:ok, Map.put(state, :socket, socket)}
        end

      {:error, :econnrefused} ->
        backoff = min(Map.get(state, :timeout, 1000), 64000)
        {:backoff, backoff, Map.put(state, :timeout, backoff * 2)}
    end
  end

  def disconnect(info, state = %{pending: pending}) do
    pending
    |> Enum.each(fn {_token, pid} ->
      Connection.reply(pid, %RethinkDB.Exception.ConnectionClosed{})
    end)

    new_state =
      state
      |> Map.delete(:socket)
      |> Map.put(:pending, %{})
      |> Map.put(:current, {:start, ""})

    # TODO: should we reconnect?
    {:stop, info, new_state}
  end

  def handle_call(:conn_opts, _from, state = %{config: opts}) do
    {:reply, opts, state}
  end

  def handle_call(_, _, state = %{pending: pending, config: %{max_pending: max_pending}})
      when map_size(pending) > max_pending do
    {:reply, %RethinkDB.Exception.TooManyRequests{}, state}
  end

  def handle_call({:query_noreply, query}, _from, state = %{token: token}) do
    new_token = token + 1
    token = <<token::little-size(64)>>
    {:noreply, state} = Request.make_request(query, token, :noreply, %{state | token: new_token})
    {:reply, :noreply, state}
  end

  def handle_call({:query, query}, from, state = %{token: token}) do
    new_token = token + 1
    token = <<token::little-size(64)>>
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

  def handle_call(:noreply_wait, from, state = %{token: token}) do
    query = "[4]"
    new_token = token + 1
    token = <<token::little-size(64)>>
    Request.make_request(query, token, from, %{state | token: new_token})
  end

  def handle_cast(:stop, state) do
    {:disconnect, :normal, state}
  end

  def handle_info({proto, _port, data}, state = %{socket: socket}) when proto in [:tcp, :ssl] do
    :ok = Transport.setopts(socket, active: :once)
    Request.handle_recv(data, state)
  end

  def handle_info({closed_msg, _port}, state) when closed_msg in [:ssl_closed, :tcp_closed] do
    {:disconnect, closed_msg, state}
  end

  def handle_info(msg, state) do
    Logger.debug("Received unhandled info: #{inspect(msg)} with state #{inspect(state)}")
    {:noreply, state}
  end

  def terminate(_reason, %{socket: socket}) do
    Transport.close(socket)
    :ok
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp handshake(socket, auth_key) do
    :ok = Transport.send(socket, <<0x400C2D20::little-size(32)>>)
    :ok = Transport.send(socket, <<:erlang.iolist_size(auth_key)::little-size(32)>>)
    :ok = Transport.send(socket, auth_key)
    :ok = Transport.send(socket, <<0x7E6970C7::little-size(32)>>)

    case recv_until_null(socket, "") do
      "SUCCESS" -> :ok
      error = {:error, _} -> error
    end
  end

  defp recv_until_null(socket, acc) do
    case Transport.recv(socket, 1) do
      {:ok, "\0"} -> acc
      {:ok, a} -> recv_until_null(socket, acc <> a)
      x = {:error, _} -> x
    end
  end
end
