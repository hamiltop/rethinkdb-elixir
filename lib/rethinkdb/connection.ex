defmodule RethinkDB.Connection do
  @moduledoc  """
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
        if Dict.has_key?(opts, :name) && opts[:name] != __MODULE__ do
          # The whole point of this macro is to provide an implicit process
          # name, so subverting it is considered an error.
          raise ArgumentError.exception(
            "Process name #{inspect opts[:name]} conflicts with implicit name #{inspect __MODULE__} provided by `use RethinkDB.Connection`"
          )
        end
        RethinkDB.Connection.start_link(Dict.put_new(opts, :name, __MODULE__))
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

      defoverridable [ start_link: 1, start_link: 0 ]
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
    timeout = Dict.get(opts, :timeout, 5000)
    conn_opts = Dict.drop(opts, [:timeout])
    noreply = Dict.get(opts, :noreply, false)
    conn_opts = Connection.call(conn, :conn_opts)
                |> Dict.take([:db])
                |> Dict.merge(conn_opts)
    query = prepare_and_encode(query, conn_opts)
    msg = case noreply do
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
      %RethinkDB.Response{data: %{"t" => 4}} -> :ok
      r -> r
    end
  end

  defp prepare_and_encode(query, opts) do
    query = RethinkDB.Prepare.prepare(query)

    # Right now :db can still be nil so we need to remove it
    opts = Enum.into(opts, %{}, fn
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

  Accepts a `Dict` of options. Supported options:

  * `:host` - hostname to use to connect to database. Defaults to `'localhost'`.
  * `:port` - port on which to connect to database. Defaults to `28015`.
  * `:user` - user to use for authentication. Defaults to `"admin"`.
  * `:pass` - password to use for authentication. Defaults to `""`.
  * `:db` - default database to use with queries. Defaults to `nil`.
  * `:sync_connect` - whether to have `init` block until a connection succeeds. Defaults to `false`.
  * `:max_pending` - Hard cap on number of concurrent requests. Defaults to `10000`
  * `:ssl` - a dict of options. Support SSL options:
      * `:ca_certs` - a list of file paths to cacerts.
  """
  def start_link(opts \\ []) do
    args = Dict.take(opts, [:host, :port, :user, :pass, :db, :sync_connect, :ssl, :max_pending])
    Connection.start_link(__MODULE__, args, opts)
  end

  def init(opts) do
    host = case Dict.get(opts, :host, 'localhost') do
      x when is_binary(x) -> String.to_char_list x
      x -> x
    end
    sync_connect = Dict.get(opts, :sync_connect, false)
    ssl = Dict.get(opts, :ssl)
    opts = Dict.put(opts, :host, host)
      |> Dict.put_new(:port, 28015)
      |> Dict.put_new(:user, "admin")
      |> Dict.put_new(:pass, "")
      |> Dict.put_new(:max_pending, 10000)
      |> Dict.drop([:sync_connect])
      |> Enum.into(%{})
    {transport, transport_opts} = case ssl do
      nil -> {%Transport.TCP{}, []}
      x -> {%Transport.SSL{}, Enum.map(Dict.fetch!(x, :ca_certs),  &({:cacertfile, &1})) ++ [verify: :verify_peer]}
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

  def connect(_info, state = %{config: %{host: host, port: port, user: user, pass: pass, transport: {transport, transport_opts}}}) do
    case Transport.connect(transport, host, port, [active: false, mode: :binary] ++ transport_opts) do
      {:ok, socket} ->
        case handshake(socket, user, pass) do
          {:error, _} -> {:stop, :bad_handshake, state}
          :ok ->
            :ok = Transport.setopts(socket, [active: :once])
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

  def handle_call(:conn_opts, _from, state = %{config: opts}) do
    {:reply, opts, state}
  end

  def handle_call(_, _,
    state = %{pending: pending, config: %{max_pending: max_pending}}) when map_size(pending) > max_pending do
    {:reply, %RethinkDB.Exception.TooManyRequests{}, state}
  end

  def handle_call({:query_noreply, query}, _from, state = %{token: token}) do
    new_token = token + 1
    token = << token :: little-size(64) >>
    {:noreply, state} = Request.make_request(query, token, :noreply, %{state | token: new_token})
    {:reply, :noreply, state}
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

  def handle_call(:noreply_wait, from, state = %{token: token}) do
    query = "[4]"
    new_token = token + 1
    token = << token :: little-size(64) >>
    Request.make_request(query, token, from, %{state | token: new_token})
  end

  def handle_cast(:stop, state) do
    {:disconnect, :normal, state};
  end

  def handle_info({proto, _port, data}, state = %{socket: socket}) when proto in [:tcp, :ssl] do
    :ok = Transport.setopts(socket, [active: :once])
    Request.handle_recv(data, state)
  end

  def handle_info({closed_msg, _port}, state) when closed_msg in [:ssl_closed, :tcp_closed] do
    {:disconnect, closed_msg, state}
  end

  def handle_info(msg, state) do
    Logger.debug("Received unhandled info: #{inspect(msg)} with state #{inspect state}")
    {:noreply, state}
  end

  def terminate(_reason, %{socket: socket}) do
    Transport.close(socket)
    :ok
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp handshake(socket, user, pass) do
    # Sends the “magic number” for the protocol version.
    case handshake_message(socket, << 0x34c2bdc3:: little-size(32) >>) do
      {:ok, %{"success" => true}} ->
        # Generates the client nonce.
        client_nonce = :crypto.strong_rand_bytes(20)
        |> Base.encode64

        client_first_message = "n=#{user},r=#{client_nonce}"

        scram = Poison.encode!(%{
          protocol_version: 0,
          authentication_method: "SCRAM-SHA-256",
          authentication: "n,,#{client_first_message}"
        })

        # Sends the “client-first-message”
        case handshake_message(socket, scram <> "\0") do
          {:ok, %{"success" => true, "authentication" => server_first_message}} ->
            auth = server_first_message
            |> String.split(",")
            |> Enum.map(&(String.split(&1, "=", parts: 2)))
            |> Enum.into(%{}, &List.to_tuple/1)

            # Verify server nonce.
            server_nonce = auth["r"]
            if String.starts_with?(server_nonce, client_nonce) do
              iter = auth["i"]
              |> String.to_integer

              salt = auth["s"]
              |> Base.decode64!

              salted_pass = RethinkDB.Connection.PBKDF2.generate(pass, salt, iterations: iter)

              client_final_message = "c=biws,r=#{server_nonce}"

              auth_msg = Enum.join([
                client_first_message,
                server_first_message,
                client_final_message
              ], ",")

              client_key = :crypto.hmac(:sha256, salted_pass, "Client Key")
              server_key = :crypto.hmac(:sha256, salted_pass, "Server Key")
              stored_key = :crypto.hash(:sha256, client_key)
              client_sig = :crypto.hmac(:sha256, stored_key, auth_msg)
              server_sig = :crypto.hmac(:sha256, server_key, auth_msg)

              proof = :crypto.exor(client_key, client_sig)
              |> Base.encode64

              scram = Poison.encode!(%{authentication: "#{client_final_message},p=#{proof}"})

              # Sends the “client-last-message”
              case handshake_message(socket, scram <> "\0") do
                {:ok, %{"success" => true, "authentication" => server_final_message}} ->
                  auth = server_final_message
                  |> String.split(",")
                  |> Enum.map(&(String.split(&1, "=", parts: 2)))
                  |> Enum.into(%{}, &List.to_tuple/1)

                  # Verifies server signature.
                  if server_sig == Base.decode64!(auth["v"]) do
                    :ok
                  else
                    {:error, "Invalid server signature"}
                  end
                {:ok, %{"success" => false, "error" => reason}} ->
                  {:error, reason}
              end
            else
              {:error, "Invalid server nonce"}
            end
          {:ok, %{"success" => false, "error" => reason}} ->
            {:error, reason}
        end
    end
  end

  defp handshake_message(sock, data) do
    with :ok 		<- Transport.send(sock, data),
        {:ok, data} <- Transport.recv(sock, 0),
    do: data
		|> String.replace_suffix("\0", "")
		|> Poison.decode
  end
end
