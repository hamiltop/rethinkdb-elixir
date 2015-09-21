defmodule RethinkDB.ConnectionTNG do
  use Connection

  require Logger

  alias RethinkDB.ConnectionTNG.Request

  def start_link(opts) do
    #TODO extract GenServer options as 3rd argument
    Connection.start_link(__MODULE__, opts)
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

  def connect(_, state = %{config: {host, port, auth_key}}) do
    case :gen_tcp.connect(host, port, [active: false, mode: :binary]) do
      {:ok, socket} ->
        :ok = handshake(socket, auth_key)
        :ok = :inet.setopts(socket, [active: :once])
        # TODO: investigate timeout vs hibernate
        {:ok, Dict.put(state, :socket, socket)}
      {:error, :econnrefused} ->
        {:backoff, 1000, state}
    end
  end

  def disconnect(_, state = %{pending: pending}) do
    pending |> Enum.each(fn {_token, pid} ->
      GenServer.reply(pid, %RethinkDB.Exception.ConnectionClosed{})
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

  defp handshake(socket, auth_key) do
    :ok = :gen_tcp.send(socket, << 0x400c2d20 :: little-size(32) >>)
    :ok = :gen_tcp.send(socket, << :erlang.iolist_size(auth_key) :: little-size(32) >>)
    :ok = :gen_tcp.send(socket, auth_key)
    :ok = :gen_tcp.send(socket, << 0x7e6970c7 :: little-size(32) >>)
    case recv_until_null(socket, "") do
      "SUCCESS" -> :ok
      error -> raise "Error in connecting: #{error}"
    end
  end

  defp recv_until_null(socket, acc) do
    case :gen_tcp.recv(socket, 1) do
      {:ok, "\0"} -> acc
      {:ok, a}    -> recv_until_null(socket, acc <> a)
    end
  end


end
