defmodule RethinkDB.Connection do
  @moduledoc """
  A module for managing connections.

  A `Connection` object is a process that can be started in various ways.

  It is recommended to start it as part of a supervision tree with a name:

      supervisor(RethinkDB.Connection, [[port: 28015, host: 'localhost', name: :rethinkdb_connection]])

  Connections will by default connect asynchronously. If a connection fails, we retry with
  an exponential backoff. All queries will return `%RethinkDB.Exception.ConnectionClosed{}`
  until the connection is established.
  """
  use DBConnection

  require Logger

  alias RethinkDB.Q
  alias RethinkDB.Connection.Multiplexer

  import DBConnection.Query, only: [decode: 3, describe: 2]

  defstruct pid: nil, options: []

  @doc """
  A convenience macro for naming connections.

  For convenience we provide the `use RethinkDB.Connection` macro, which automatically registers
  itself under the module name:

      defmodule FooDatabase, do: use RethinkDB.Connection

  Then in the supervision tree:

      worker(FooDatabase, [[port: 28015, host: 'localhost']])

  When `use RethinkDB.Connection` is called, it will define:

  * `start_link`
  * `run`
  * `norepy_wait`
  * `stop`

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

  Accepts a `Keyword` of options. Supported options:

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
  * `:profile`  - Query profiling.
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
  def next(%{token: token, pid: pid}) do
    query = %Q{message: "[2]"}
    case Multiplexer.send_recv(pid, query.message, token: token, timeout: :infinity) do
      {:ok, {token, data}} ->
        decode(query, {token, data, pid}, [])
    end
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
    # Starts the multiplexer process and stores its pid and some default options to the state.
    {:ok, pid} = Multiplexer.start_link(options)
    {:ok, %__MODULE__{pid: pid, options: Keyword.take(options, ~w(db database timeout)a)}}
  end

  def disconnect(_err, _state) do
    # TODO
  end

  def checkin(state) do
    {:ok, state}
  end

  def checkout(state) do
    {:ok, state}
  end

  def handle_execute(%Q{message: message} = query, _params, options, %__MODULE__{pid: pid} = state) do
    # Overrides default options with specified ones.
    options = Keyword.merge(state.options, options)

    unless message do
      # This only applies when called with run/3 and is used
      # to support default options when encoding the query.
      message = describe(query, options)
      |> Map.fetch!(:message)
    end

    case Multiplexer.send_recv(pid, message, options) do
      :ok ->
        {:ok, nil, state}
      {:ok, {token, data}} ->
        {:ok, {token, data, pid}, state}
    end
  end

  def handle_close(_query, _options, state) do
    {:ok, nil, state}
  end
end
