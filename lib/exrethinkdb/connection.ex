defmodule Exrethinkdb.Connection do
  use GenServer
  import  Exrethinkdb.Ql2
  alias Exrethinkdb.Ql2
  alias Exrethinkdb.RqlDriverError

  @proto_version  Ql2.VersionDummy.Version |> Map.from_struct|> Map.get(:V0_4)

  @proto_protocol  Ql2.VersionDummy.Protocol |> Map.from_struct|> Map.get(:JSON)
  @proto_query_type  Ql2.Query.QueryType |> Map.from_struct


  @proto_response_type  Ql2.Response.ResponseType |> Map.from_struct

  def start_link(opts \\ []) do
    opts = Dict.put_new(opts, :name, __MODULE__)
    args = Dict.take(opts, [:host, :port])
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init(opts) do
    host = Dict.get(opts, :host, {127,0,0,1})
    port = Dict.get(opts, :port, 28015)
    auth_key = Dict.get(opts, :auth_key, "")
    socket = connect(host, port,auth_key)
    :ok = :inet.setopts(socket, [active: true])
    {:ok, %{pending: %{}, current: {:start, ""}, socket: socket, token: 0}}
  end

  defp connect(host, port,auth_key) do
    {:ok, socket} = :gen_tcp.connect(host, port, [active: false, mode: :binary])
    :ok = handshake(socket,auth_key)
    socket
  end

  defp handshake(socket,auth_key) do
        :ok = :gen_tcp.send(socket, :binary.encode_unsigned(@proto_version,:little))
        :ok = :gen_tcp.send(socket, << :erlang.iolist_size(auth_key) :: little-size(32) >>)
        :ok = :gen_tcp.send(socket, auth_key)
        :ok = :gen_tcp.send(socket, :binary.encode_unsigned(@proto_protocol,:little) )

        case :gen_tcp.recv(socket, 8) do

            {:ok, "SUCCESS" <> << 0 :: size(8)  >>} -> :ok
            response   -> raise RqlDriverError, msg: "Invalid Auth Key"


        end

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
