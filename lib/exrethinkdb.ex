defmodule Exrethinkdb do
 
  def connect(opts \\ []) do
    {:ok, pid} = Exrethinkdb.Connection.start_link(opts)  
    pid
  end

  def run(pid \\ Exrethinkdb.Connection, query) do
    query = prepare_and_encode(query)
    {response, token} = GenServer.call(pid, {:query, query})
    Exrethinkdb.Response.parse(response, token, pid)
  end

  def next(%{token: token, pid: pid}) do
    {response, token} = GenServer.call(pid, {:continue, token}, :infinity)
    Exrethinkdb.Response.parse(response, token, pid)
  end

  def prepare_and_encode(query) do
    query = Exrethinkdb.Query.prepare(query)
    Poison.encode!([1, query])      
  end
end
