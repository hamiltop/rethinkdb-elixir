defmodule Exrethinkdb do
  defmodule Connection do
    defstruct socket: nil
  end

  def local_connection do
    connect 'localhost', 28015
  end

  def connect(host, port) do
    {:ok, socket} = :gen_tcp.connect(host, port, [active: false, mode: :binary])
    :ok = handshake(socket)
    socket
  end

  def handshake(socket) do
    :ok = :gen_tcp.send(socket, << 0x400c2d20 :: little-size(32) >>)
    :ok = :gen_tcp.send(socket, << 0 :: little-size(32) >>)
    :ok = :gen_tcp.send(socket, << 0x7e6970c7 :: little-size(32) >>)
    {:ok, "SUCCESS" <> << 0 :: size(8)  >>} = :gen_tcp.recv(socket, 8)
    :ok
  end

  def execute_query(socket, q) do
    token = <<1 :: size(64)>>
    :ok = :gen_tcp.send(socket, token)
    bsize = :erlang.size(q)
    :ok = :gen_tcp.send(socket, << bsize :: little-size(32) >>)
    :ok = :gen_tcp.send(socket, q)
    {:ok, ^token} = :gen_tcp.recv(socket, :erlang.size(token))
    {:ok, << length :: little-size(32) >>} = :gen_tcp.recv(socket, 4)
    {:ok, response} = :gen_tcp.recv(socket, length)
  end

  def run(socket, query) do
    {:ok, response} = execute_query(socket, Poison.encode!([1, query]))
    %{"r" => result} = Poison.decode!(response)
    result
  end
end
