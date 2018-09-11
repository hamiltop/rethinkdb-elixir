defmodule RethinkDB.Connection.Transport do
  defmodule(SSL, do: defstruct([:socket]))
  defmodule(TCP, do: defstruct([:socket]))

  def connect(%SSL{}, host, port, opts) do
    case :ssl.connect(host, port, opts) do
      {:ok, socket} -> {:ok, %SSL{socket: socket}}
      x -> x
    end
  end

  def connect(%TCP{}, host, port, opts) do
    case :gen_tcp.connect(host, port, opts) do
      {:ok, socket} -> {:ok, %TCP{socket: socket}}
      x -> x
    end
  end

  def send(%SSL{socket: socket}, data) do
    :ssl.send(socket, data)
  end

  def send(%TCP{socket: socket}, data) do
    :gen_tcp.send(socket, data)
  end

  def recv(%SSL{socket: socket}, n) do
    :ssl.recv(socket, n)
  end

  def recv(%TCP{socket: socket}, n) do
    :gen_tcp.recv(socket, n)
  end

  def setopts(%SSL{socket: socket}, opts) do
    :ssl.setopts(socket, opts)
  end

  def setopts(%TCP{socket: socket}, opts) do
    :inet.setopts(socket, opts)
  end

  def close(%SSL{socket: socket}), do: :ssl.close(socket)
  def close(%TCP{socket: socket}), do: :gen_tcp.close(socket)
end
