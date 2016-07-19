defmodule RethinkDB.Connection.Multiplexer do
  @moduledoc """
  This module provides functions to multiplex messages over a single `:gen_tcp`
  connection.

  Each request message sent to the server has a unique 8-byte token assigned. The
  server will send responses using this token as an identifier so the reply can
  be matched to its request.

  Each message is encoded in following format:

  * The 8-byte unique message token.
  * The length of the message, as a 4 byte little-endian integer.
  * The message content.

  The advantage of using this approach is that it allows the server to process
  multiple requests in parallel on the same connection. For the client, this
  means that replies can arrive in any order.
  """
  use GenServer

  import DBConnection.ConnectionError, only: [exception: 1]

  @doc false
  defstruct conn: {nil, nil}, token: 1, pending: %{}, current: {:start, ""}

  @doc """
  Starts a `Connection` process linked to the current process.
  """
  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, [])
  end

  @doc """
  Sends the given `message` to the server.

  Options:

  * `:timeout` - maximum time to wait for a reply (default: `5_000`).
  * `:noreply` - do not wait for the server acknowledgement of the message.
  """
  def send_recv(pid, message, options \\ []) do
    noreply = Keyword.get(options, :noreply, false)
    timeout = Keyword.get(options, :timeout, 5_000)
    if noreply do
      GenServer.cast(pid, {:send, message})
    else
      token = Keyword.get(options, :token)
      {:ok, GenServer.call(pid, {:send, token, message}, timeout)}
    end
  end

  #
  # GenServer API
  #

  def init(options) do
    host = Keyword.get(options, :hostname, "localhost")
    port = Keyword.get(options, :port, 28015)
    user = Keyword.get(options, :user, "admin")
    pass = Keyword.get(options, :password, "")

    {transport, sock_opts} =
      if ssl_opts = Keyword.get(options, :ssl) do
        {:ssl, Enum.map(Keyword.fetch!(ssl_opts, :ca_certs),  &({:cacertfile, &1})) ++ [verify: :verify_peer]}
      else
        {:gen_tcp, []}
      end

    # Connects to the server and perform a handshake
    sock_opts = [packet: :raw, mode: :binary, active: :false] ++ sock_opts
    with {:ok, sock} <- transport.connect(String.to_char_list(host), port, sock_opts),
         {:ok, conn} <- init_connection(transport, sock),
         {:ok, _nil} <- handshake(conn, user, pass),
         {:ok, conn} <- init_connection(transport, sock, active: :once),
    do:  {:ok, %__MODULE__{conn: conn}}
  end

  def handle_call({:send, nil, msg}, from, %__MODULE__{conn: conn, token: token, pending: pending} = state) do
    :ok = send_payload(conn, token, msg)
    pending = Map.put(pending, token, from)
    {:noreply, %__MODULE__{state | token: token + 1, pending: pending}}
  end

  def handle_call({:send, token, msg}, from, %__MODULE__{conn: conn, pending: pending} = state) do
    :ok = send_payload(conn, token, msg)
    pending = Map.put(pending, token, from)
    {:noreply, %__MODULE__{state | pending: pending}}
  end

  def handle_cast({:send, msg}, %__MODULE__{conn: conn, token: token} = state) do
    :ok = send_payload(conn, token, msg)
    {:noreply, %__MODULE__{state | token: token + 1}}
  end

  def handle_info({protocol, port, data}, %__MODULE__{conn: {transport, sock}} = state) when protocol in [:tcp, :ssl] and sock == port do
    init_connection(transport, sock, active: true)
    {:noreply, recv_payload(data, state)}
  end

  def handle_info({closed_msg, port}, %__MODULE__{conn: {_transport, sock}} = state) when closed_msg in [:ssl_closed, :tcp_closed] and sock == port do
    {:stop, closed_msg, state}
  end

  defp init_connection(transport, sock, options \\ []) do
    unless options == [] do
      case transport do
        :gen_tcp ->
          :inet.setopts(sock, options)
        :ssl ->
          :ssl.setopts(sock, options)
      end
    end
    {:ok, {transport, sock}}
  end


  #
  # Handshake V1_0
  #

  defp handshake(conn, user, pass) do
    # Sends the “magic number” for the protocol version.
    case handshake_message(conn, << 0x34c2bdc3:: little-size(32) >>) do
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
        case handshake_message(conn, scram <> "\0") do
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
              case handshake_message(conn, scram <> "\0") do
                {:ok, %{"success" => true, "authentication" => server_final_message}} ->
                  auth = server_final_message
                  |> String.split(",")
                  |> Enum.map(&(String.split(&1, "=", parts: 2)))
                  |> Enum.into(%{}, &List.to_tuple/1)

                  # Verifies server signature.
                  if server_sig == Base.decode64!(auth["v"]) do
                    {:ok, nil}
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

  defp handshake_message({transport, sock}, data) do
    with :ok <- transport.send(sock, data),
        {:ok, data} <- transport.recv(sock, 0),
    do: String.replace_suffix(data, "\0", "") |> Poison.decode
  end

  #
  # TCP/SSL request-reply
  #

  defp send_payload({transport, sock}, token, msg) do
    transport.send(sock, << token :: little-size(64), byte_size(msg) :: little-size(32) >> <> msg)
  end

  def recv_payload(data, %__MODULE__{current: {:start, leftover}} = state) do
   case leftover <> data do
     << token :: little-size(64), leftover :: binary >> ->
       recv_payload("", %__MODULE__{state | current: {:token, token, leftover}})
     new_data ->
       %__MODULE__{state | current: {:start, new_data}}
   end
 end

 def recv_payload(data, state = %__MODULE__{current: {:token, token, leftover}}) do
   case leftover <> data do
     << length :: little-size(32), leftover :: binary >> ->
       recv_payload("", %__MODULE__{state | current: {:length, length, token, leftover}})
     new_data ->
       %__MODULE__{state | current: {:token, token, new_data}}
   end
 end

 def recv_payload(data, state = %{current: {:length, length, token, leftover}, pending: pending}) do
   case leftover <> data do
     << reply :: binary-size(length), leftover :: binary >> ->
      {from, pending} = Map.pop(pending, token)
      if from, do: GenServer.reply(from, {token, reply})
      recv_payload("", %__MODULE__{state | current: {:start, leftover}, pending: pending})
     new_data ->
       %__MODULE__{state | current: {:length, length, token, new_data}}
   end
 end
end
