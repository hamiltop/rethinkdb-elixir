defmodule RethinkDB.Connection do
  use Connection

  require Logger

  alias RethinkDB.Connection.Request

  defmacro __using__(_opts) do
    quote do
      defmacro __using__(_opts) do
        quote do
          import RethinkDB.Query
          import unquote(__MODULE__)
        end
      end

      def start_link(opts \\ []) do
        RethinkDB.Connection.start_link(Dict.put_new(opts, :name, __MODULE__))
      end

      def connect(opts \\ []) do
        RethinkDB.Connection.connect(Dict.put_new(opts, :name, __MODULE__))    
      end

      def run(query) do
        RethinkDB.Connection.run(query, __MODULE__)  
      end

      def stop do
        RethinkDB.Connection.stop(__MODULE__)
      end

      defdelegate next(query), to: RethinkDB.Connection
      defdelegate close(query), to: RethinkDB.Connection
      defdelegate prepare_and_encode(query), to: RethinkDB.Connection
    end
  end

  def run(query, pid) do
    query = prepare_and_encode(query)
    case Connection.call(pid, {:query, query}) do
      {response, token} -> RethinkDB.Response.parse(response, token, pid)
      result -> result
    end
  end

  def next(%{token: token, pid: pid}) do
    case Connection.call(pid, {:continue, token}, :infinity) do
      {response, token} -> RethinkDB.Response.parse(response, token, pid)
      x -> x
    end
  end

  def stop(pid) do
    Connection.cast(pid, :stop)
  end

  def close(%{token: token, pid: pid}) do
    {response, token} = Connection.call(pid, {:stop, token}, :infinity)
    RethinkDB.Response.parse(response, token, pid)
  end

  def prepare_and_encode(query) do
    query = RethinkDB.Prepare.prepare(query)
    Poison.encode!([1, query])      
  end


  def start_link(opts \\ []) do
    args = Dict.take(opts, [:host, :port, :auth_key])
    Connection.start_link(__MODULE__, args, opts)
  end

  def init(opts) do
    host = case Dict.get(opts, :host, 'localhost') do
      x when is_binary(x) -> String.to_char_list x
      x -> x
    end
    port = Dict.get(opts, :port, 28015)
    auth_key = Dict.get(opts, :auth_key, "")
    state = %{
      pending: %{},
      current: {:start, ""},
      token: 0,
      config: {host, port, auth_key}
    }
    {:connect, :init, state}
  end

  def connect(opts \\ []) do
    {:ok, pid} = RethinkDB.Connection.start_link(opts)  
    pid
  end

  def connect(_info, state = %{config: {host, port, auth_key}}) do
    case :gen_tcp.connect(host, port, [active: false, mode: :binary]) do
      {:ok, socket} ->
        case handshake(socket, auth_key) do
          {:error, _} -> {:stop, :normal, state}
          :ok ->
            :ok = :inet.setopts(socket, [active: :once])
            # TODO: investigate timeout vs hibernate
            {:ok, Dict.put(state, :socket, socket)}
        end
      {:error, :econnrefused} ->
        backoff = min(Dict.get(state, :timeout, 1000), 64000)
        {:backoff, backoff, Dict.put(state, :timeout, backoff)}
    end
  end

  def disconnect(_info, state = %{pending: pending}) do
    pending |> Enum.each(fn {_token, pid} ->
      Connection.reply(pid, %RethinkDB.Exception.ConnectionClosed{})
    end)
    new_state = state
      |> Map.delete(:socket)
      |> Map.put(:pending, %{})
      |> Map.put(:current, {:start, ""})
    # TODO: should we reconnect?
    {:stop, :normal, new_state}
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

  def handle_cast(:stop, state) do
    {:disconnect, :stop_called, state};
  end

  def handle_info({:tcp, _port, data}, state = %{socket: socket}) do
    :ok = :inet.setopts(socket, [active: :once])
    Request.handle_recv(data, state)
  end

  def handle_info({:tcp_closed, _port}, state) do
    {:disconnect, :closed, state}
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
