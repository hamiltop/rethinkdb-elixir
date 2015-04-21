defmodule Exrethinkdb.ConnectionServer do
  use GenServer

  def init(_opts) do
    socket = Exrethinkdb.local_connection
    :ok = :inet.setopts(socket, [active: true])
    {:ok, %{pending: %{}, current: {:start, ""}, socket: socket, token: 0}}
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

  def handle_info(a, state) do
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
