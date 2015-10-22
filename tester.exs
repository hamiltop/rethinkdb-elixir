import RethinkDB.Query

c = RethinkDB.connect
d = RethinkDB.connect
f = RethinkDB.connect
g = RethinkDB.connect

q = 1..12 |> Enum.reduce("hi", fn (_, acc) ->
          add(acc, acc)
        end)

1..10 |> Enum.map(fn (_) ->
  {r, _} = :timer.tc(fn ->
    1..10 |> Enum.map(fn (_) ->
      Task.async fn ->
        e = Enum.random([c,c,c,c])
        q |> RethinkDB.run(e, :infinity)
      end
    end) |> Enum.map(&Task.await(&1, :infinity))
  end)

  IO.inspect r
end)
