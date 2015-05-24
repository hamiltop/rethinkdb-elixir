defmodule RethinkDB.Record do
  defstruct data: ""
end

defmodule RethinkDB.Collection do
  defstruct data: []
end

defmodule RethinkDB.OrderByLimitFeed do
  defstruct token: nil, data: [], pid: nil

  defimpl Enumerable, for: __MODULE__ do
    def reduce(feed = %{data: data}, acc, fun) do
      stream = Stream.repeatedly(fn ->
        RethinkDB.next(feed)
      end) |> Stream.flat_map(fn (el) ->
        el.data
      end) |> Stream.scan(data, fn
        (%{"new_val" => new, "old_val" => old}, acc) ->
        index = Enum.find_index(acc, &(&1 == old))
        List.replace_at(acc, index, new)
      end)
      Enumerable.reduce(stream, acc, fun)
    end
    def count(_changes), do: raise "count/1 not supported for OrderByLimitFeed"
    def member?(_changes, _values), do: raise "member/2 not supported for OrderByLimitFeed"
  end
end

defmodule RethinkDB.Feed do
  defstruct token: nil, data: nil, pid: nil, note: nil

  defimpl Enumerable, for: __MODULE__ do
    def reduce(changes, acc, fun) do
      stream = Stream.unfold(changes, fn
        x = %RethinkDB.Feed{} -> {x, RethinkDB.next(x)}
        x = %RethinkDB.Collection{} -> {x, nil}
        nil -> nil
      end) |> Stream.flat_map(fn (el) ->
        el.data
      end)
      stream.(acc, fun)
    end
    def count(_changes), do: raise "count/1 not supported for changes"
    def member?(_changes, _values), do: raise "member/2 not supported for changes"
  end
end

defmodule RethinkDB.Response do
  defstruct token: nil, data: ""

  def parse(raw_data, token, pid) do
    d = Poison.decode!(raw_data)
    data = RethinkDB.Pseudotypes.convert_reql_pseudotypes(d["r"])
    case d["t"] do
      1  -> %RethinkDB.Record{data: hd(data)}
      2  -> %RethinkDB.Collection{data: data}
      3  -> case d["n"] do
          [2] -> %RethinkDB.Feed{token: token, data: hd(data), pid: pid, note: d["n"]}
           _  -> %RethinkDB.Feed{token: token, data: data, pid: pid, note: d["n"]}
        end
      4  -> %RethinkDB.Response{token: token, data: d}
      16  -> %RethinkDB.Response{token: token, data: d}
      17  -> %RethinkDB.Response{token: token, data: d}
      18  -> %RethinkDB.Response{token: token, data: d}
    end
  end

  def to_order_by_limit_feed(%{token: token, pid: pid, data: data, note: [3]}) do
    data = data |> Enum.map(fn (el) -> el["new_val"] end)
    %RethinkDB.OrderByLimitFeed{token: token, data: data, pid: pid}
  end
end

