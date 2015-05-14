defmodule RethinkDB.Connection do
  use GenServer

  defmacro __using__(_opts) do
    quote do
      defmacro __using__(_opts) do
        quote do
          use RethinkDB.Query
          import unquote(__MODULE__)
        end
      end
      def connect(opts \\ []) do
        RethinkDB.Connection.connect(Dict.put_new(opts, :name, __MODULE__))    
      end

      def run(query) do
        RethinkDB.Connection.run(query, __MODULE__)  
      end

      defdelegate next(query), to: RethinkDB.Connection
      defdelegate prepare_and_encode(query), to: RethinkDB.Connection
    end
  end

  def connect(opts \\ []) do
    {:ok, pid} = RethinkDB.Connection.start_link(opts)  
    pid
  end

  def run(query, pid) do
    query = prepare_and_encode(query)
    {response, token} = GenServer.call(pid, {:query, query})
    RethinkDB.Response.parse(response, token, pid)
  end

  def next(%{token: token, pid: pid}) do
    {response, token} = GenServer.call(pid, {:continue, token}, :infinity)
    RethinkDB.Response.parse(response, token, pid)
  end

  def prepare_and_encode(query) do
    query = RethinkDB.Prepare.prepare(query)
    Poison.encode!([1, query])      
  end

  def start_link(opts \\ []) do
    args = Dict.take(opts, [:host, :port])
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init(opts) do
    host = Dict.get(opts, :host, 'localhost')
    port = Dict.get(opts, :port, 28015)
    socket = connect(host, port)
    :ok = :inet.setopts(socket, [active: true])
    {:ok, %{pending: %{}, current: {:start, ""}, socket: socket, token: 0}}
  end

  defp connect(host, port) do
    host = case host do
       x when is_binary(x) -> String.to_char_list x
       x -> x
    end
    {:ok, socket} = :gen_tcp.connect(host, port, [active: false, mode: :binary])
    :ok = handshake(socket)
    socket
  end

  defp handshake(socket) do
    :ok = :gen_tcp.send(socket, << 0x400c2d20 :: little-size(32) >>)
    :ok = :gen_tcp.send(socket, << 0 :: little-size(32) >>)
    :ok = :gen_tcp.send(socket, << 0x7e6970c7 :: little-size(32) >>)
    {:ok, "SUCCESS" <> << 0 :: size(8)  >>} = :gen_tcp.recv(socket, 8)
    :ok
  end


  def handle_call({:query, query}, from, state = %{token: token}) do
    new_token = token + 1
    token = << token :: little-size(64) >>
    make_request(query, token, from, %{state | token: new_token}) 
  end

  def handle_call({:continue, token}, from, state) do
    query = "[2]"
    make_request(query, token, from, state)
  end

  def make_request(query, token, from, state = %{pending: pending, socket: socket}) do
    new_pending = Dict.put_new(pending, token, from)
    bsize = :erlang.size(query)
    payload = token <> << bsize :: little-size(32) >> <> query
    :ok = :gen_tcp.send(socket, payload)
    {:noreply, %{state | pending: new_pending}}
  end

  def handle_info({:tcp, _, data}, state) do
    handle_recv(data, state)
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def handle_recv(data, state = %{current: {:start, leftover}}) do
    case leftover <> data do
      << token :: binary-size(8), leftover :: binary >> ->
        handle_recv("", %{state | current: {:token, token, leftover}})
      new_data ->
        {:noreply, %{state | current: {:start, new_data}}}
    end
  end
  def handle_recv(data, state = %{current: {:token, token, leftover}}) do
    case leftover <> data do
      << length :: little-size(32), leftover :: binary >> ->
        handle_recv("", %{state | current: {:length, length, token, leftover}})
      new_data ->
        {:noreply, %{state | current: {:token, token, new_data}}}
    end
  end
  def handle_recv(data, state = %{current: {:length, length, token, leftover}, pending: pending}) do
    case leftover <> data do
      << response :: binary-size(length), leftover :: binary >> ->
        GenServer.reply(pending[token], {response, token})
        handle_recv("", %{state | current: {:start, leftover}, pending: Dict.delete(pending, token)})
      new_data ->
        {:noreply, %{state | current: {:length, length, token, new_data}}}
    end
  end
end
