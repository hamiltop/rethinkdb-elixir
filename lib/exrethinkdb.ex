defmodule Exrethinkdb do
 
  def connect(opts \\ []) do
    {:ok, pid} = Exrethinkdb.Connection.start_link(opts)  
    pid
  end

  def run(pid \\ Exrethinkdb.Connection, query) do
    {response, token} = GenServer.call(pid, {:query, Poison.encode!([1, query])})
    Exrethinkdb.Response.parse(response, token, pid)
  end

  def next(%{token: token, pid: pid}) do
    {response, token} = GenServer.call(pid, {:continue, token}, :infinity)
    Exrethinkdb.Response.parse(response, token, pid)
  end
end
