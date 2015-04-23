defmodule Exrethinkdb do
  def local_connection do
    connect('localhost', 28015)
  end
 
  def connect(host, port) do
    {:ok, pid} = GenServer.start_link(Exrethinkdb.Connection, [%{host: host, port: port}])  
    %Exrethinkdb.Connection{pid: pid}
  end

  def run(conn = %Exrethinkdb.Connection{pid: pid}, query) do
    {response, token} = GenServer.call(pid, {:query, Poison.encode!([1, query])})
    Exrethinkdb.Response.parse(response, token)
  end
end
