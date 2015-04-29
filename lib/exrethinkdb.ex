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
    %{query: query} = prepare(query, %{query: [], vars: {0, %{}}})
    Poison.encode!([1, query])      
  end

  def prepare([h | t], %{query: query, vars: vars}) do
    %{query: new_query, vars: new_vars} = prepare(h, %{query: [], vars: vars})
    prepare(t, %{query: query ++ [new_query], vars: new_vars})   
  end
  def prepare([], acc) do
    acc
  end
  def prepare(ref, %{query: query, vars: {max, map}}) when is_reference(ref) do
    case Dict.get(map, ref) do
      nil ->
        %{
          query: query ++ (max + 1),
          vars: {max + 1, Dict.put_new(map, ref, max + 1)}
        }
      x ->
        %{
          query: query ++ x,
          vars: {max, map}
        }
    end 
  end
  def prepare(el, %{query: query, vars: vars}) do
    %{query: query ++ el, vars: vars}
  end
end
