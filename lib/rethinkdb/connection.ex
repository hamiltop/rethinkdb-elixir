defmodule RethinkDB.Connection do
  @moduledoc  """
  A module for managing connections.

  A `Connection` object is a process that can be started in various ways.

  It is recommended to start it as part of a supervision tree with a name:

      worker(RethinkDB.Connection, [[port: 28015, host: 'localhost', name: :rethinkdb_connection]])

  Connections will by default connect asynchronously. If a connection fails, we retry with
  an exponential backoff. All queries will return `%RethinkDB.Exception.ConnectionClosed{}`
  until the connection is established.
  """
  use DBConnection

  require Logger

  alias RethinkDB.Q

  import DBConnection.Query, only: [describe: 2]
  import DBConnection.Error, only: [exception: 1]

  @transport :gen_tcp

  defmodule State do
    defstruct sock: nil, token: 1, options: []
  end

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

      def noreply_wait(timeout \\ 15_000) do
        RethinkDB.Connection.noreply_wait(__MODULE__, timeout)
      end

      def stop do
        RethinkDB.Connection.stop(__MODULE__)
      end

      defoverridable [ start_link: 1, start_link: 0 ]
    end
  end

  @doc """
  Start connection as a linked process

  Accepts a `Dict` of options. Supported options:

  * `:host` - Hostname to use to connect to database. Defaults to `"localhost"`.
  * `:port` - Port on which to connect to database. Defaults to `28015`.
  * `:database` - Default database to use for query.
  * `:user` - User to use for authentication. Defaults to `"admin"`.
  * `:pass` - Password to use for authentication. Defaults to `""`.
  * `:timeout`  - How long to wait for a response.
  """
  def start_link(options \\ []) do
    DBConnection.start_link(__MODULE__, options)
  end

  @doc """
  Run a query on a connection.

  Supports the following options:

  * `:timeout`  - How long to wait for a response.
  * `:profile`  - Query profiling. Defaults to `false`.
  * `:database` - Database to use for query.
  """
  def run(query, conn, options \\ []) do
    DBConnection.execute!(conn, query, [], options)
  end

  @doc """
  Fetch the next dataset for a feed.

  Since a feed is tied to a particular connection, no connection is needed when calling
  `next`.
  """
  def next(%{token: token, pid: conn}) do
    DBConnection.execute!(conn, %Q{message: "[2]"}, [], token: token, timeout: :infinity)
  end

  @doc """
  Stop the connection.

  Stops the given connection.
  """
  def stop(_conn) do
    :ok # TODO
  end

  @doc """
  Closes a feed.

  Since a feed is tied to a particular connection, no connection is needed when calling
  `close`.
  """
  def close(%{token: token, pid: conn}) do
    DBConnection.execute!(conn, %Q{message: "[3]"}, [], token: token)
  end

  @doc """
  `noreply_wait` ensures that previous queries with the noreply flag have been processed by the server. Note that this guarantee only applies to queries run on the given connection.
  """
  def noreply_wait(conn, timeout \\ 15_000) do
    DBConnection.execute!(conn, %Q{message: "[3]"}, [], timeout: timeout)
  end

  #
  # DBConnection API
  #

  def connect(options) do
    host = Keyword.get(options, :hostname, "localhost")
    port = Keyword.get(options, :port, 28015)
    user = Keyword.get(options, :user, "admin")
    pass = Keyword.get(options, :password, "")

    # Following options are stored into the state
    # and are used as default options when calling run/3.
    conn_opts = Keyword.take(options, ~w(database timeout))

    # Connects to the server and perform a handshake
    sock_opts = [packet: :raw, mode: :binary, active: :false]
    case @transport.connect(String.to_char_list(host), port, sock_opts, Keyword.get(options, :timeout, 15_000)) do
      {:ok, sock} ->
        handshake(user, pass, %State{sock: sock, options: conn_opts})
      {:error, :econnrefused} ->
        {:error, exception("Connection refused")}
    end
  end

  def disconnect(_err, %State{sock: sock}) do
    @transport.close(sock)
  end

  def checkin(%State{sock: sock} = state) do
    # Socket is back with the owning process, activate it
    # to handle error/closed messages via handle_info/2.
    case :inet.setopts(sock, active: true) do
      :ok ->
        {:ok, state}
      {:error, _err} ->
        {:disconnect, exception("Failed to checkin socket"), state}
    end
  end

  def checkout(%State{sock: sock} = state) do
    # Socket is going to be used by another process,
    # deactive message forwarding to handle_info/2.
    case :inet.setopts(sock, active: false) do
      :ok ->
        {:ok, state}
      {:error, _err} ->
        {:disconnect, exception("Failed to checkout socket"), state}
    end
  end

  def handle_execute(%Q{message: message} = query, _params, options, %State{sock: sock, token: token} = state) do
    # Overrides default options with specified ones.
    options = Keyword.merge(state.options, options)
    timeout = Keyword.get(options, :timeout, 15_000)

    unless message do
      # This only applies when called with run/3 and is used
      # to support default options when encoding the query.
      message = describe(query, options)
      |> Map.fetch!(:message)
    end

    # This is used to retrieve more data for the cursor
    # on the same connection with the same token.
    token = Keyword.get(options, :token, token)

    # Assigns the query to the given token.
    payload = << token :: little-size(64), byte_size(message) :: little-size(32) >> <> message

    if Keyword.get(options, :noreply, false) do
      # If :noreply mode is enabled, we do not wait for the server
      # acknowledgement of the query before moving on to the next query.
      @transport.send(sock, payload)
      {:ok, nil, state}
    else
      # 1) Sends the query.
      # 2) Reads the response header.
      # 3) Reads the response body.
      # 5) Increments the token.
      with :ok <- @transport.send(sock, payload),
          {:ok, << ^token :: little-size(64), data_size :: little-size(32) >>} <- @transport.recv(sock, 12, timeout),
          {:ok, data} <- @transport.recv(sock, data_size, timeout),
      do: {:ok, {data, token, sock}, %{state | token: token + 1}}
    end
  end

  def handle_close(_query, _options, state) do
    {:ok, nil, state}
  end

  def handle_info({:tcp, _sock, message}, state) do
    Logger.warn "Unhandled message: #{inspect message}"
    {:ok, state}
  end

  def handle_info({:tcp_closed, _sock}, state) do
    {:disconnect, exception("Connection closed"), state}
  end

  def handle_info({:tcp_error, _sock, _err}, state) do
    {:disconnect, exception("Connection error"), state}
  end

  def handle_info(message, state) do
    Logger.debug "Unhandled message: #{inspect message}"
    {:ok, state}
  end

  #
  # Handshake V1_0
  #

  defp handshake(user, pass, %State{sock: sock} = state) do
    # Sends the “magic number” for the protocol version.
    case handshake_message(<< 0x34c2bdc3:: little-size(32) >>, sock) do
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
        case handshake_message(scram <> "\0", sock) do
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

              salted_pass = __MODULE__.PBKDF2.generate(pass, salt, iterations: iter)

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
              case handshake_message(scram <> "\0", sock) do
                {:ok, %{"success" => true, "authentication" => server_final_message}} ->
                  auth = server_final_message
                  |> String.split(",")
                  |> Enum.map(&(String.split(&1, "=", parts: 2)))
                  |> Enum.into(%{}, &List.to_tuple/1)

                  # Verifies server signature.
                  if server_sig == Base.decode64!(auth["v"]) do
                    {:ok, state}
                  else
                    {:error, exception("Invalid server signature")}
                  end
                {:ok, %{"success" => false, "error" => reason}} ->
                  {:error, exception(reason)}
              end
            else
              {:error, exception("Invalid server nonce")}
            end
          {:ok, %{"success" => false, "error" => reason}} ->
            {:error, exception(reason)}
        end
    end
  end

  defp handshake_message(data, sock) do
    with :ok <- @transport.send(sock, data),
        {:ok, data} <- @transport.recv(sock, 0),
    do: String.replace_suffix(data, "\0", "") |> Poison.decode
  end
end
