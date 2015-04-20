spawn_link fn ->
  {:ok, pid} = GenServer.start_link(Exrethinkdb.ConnectionServer, [])
  a = fn _ -> GenServer.call(pid, {:query, Poison.encode!([1, Exrethinkdb.Query.table("people")])}, :infinity) end
  (1..20000) |> Enum.map(fn _ -> Task.async fn -> a.(0) end end) |> Enum.map &(Task.await(&1, :infinity))
end
{:ok, pid} = GenServer.start_link(Exrethinkdb.ConnectionServer, [])
a = fn _ -> GenServer.call(pid, {:query, Poison.encode!([1, Exrethinkdb.Query.table("people")])}, :infinity) end
(1..20000) |> Enum.map(fn _ -> Task.async fn -> a.(0) end end) |> Enum.map &(Task.await(&1, :infinity))
