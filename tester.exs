import RethinkDB.Query

c = RethinkDB.connect

1..10 |> Enum.map(fn (_) ->
  {r, _} = :timer.tc(fn ->
    1..100 |> Enum.map(fn (_) ->
      Task.async fn ->
        1..1 |> Enum.reduce(1, fn (_, acc) ->
          add(acc, 1)
        end) |> RethinkDB.run(c, :infinity)
      end
    end) |> Enum.map(&Task.await(&1, :infinity))
  end)

  IO.inspect r
end)
