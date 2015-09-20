defmodule RethinkDB.Connection.Request do

  def make_request(query, token, from, state = %{pending: pending, socket: socket}) do
    new_pending = Dict.put_new(pending, token, from)
    bsize = :erlang.size(query)
    payload = token <> << bsize :: little-size(32) >> <> query
    case :gen_tcp.send(socket, payload) do
      :ok -> {:noreply, %{state | pending: new_pending}}
      {:error, :closed} -> {:reply, %RethinkDB.Exception.ConnectionClosed{}, state}
    end
  end

  def make_request(_query, _token, _from, state) do
    {:reply, %RethinkDB.Exception.ConnectionClosed{}, state}
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
