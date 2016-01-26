defmodule RethinkDB.Record do
  @moduledoc false
  defstruct data: "", profile: nil
end

defmodule RethinkDB.Collection do
  @moduledoc false
  defstruct data: [], profile: nil

  defimpl Enumerable, for: __MODULE__ do
    def reduce(%{data: data}, acc, fun) do
      Enumerable.reduce(data, acc, fun)
    end

    def count(%{data: data}), do: Enumerable.count(data)
    def member?(%{data: data}, el), do: Enumerable.member?(data, el)
  end
end

defmodule RethinkDB.Feed do
  @moduledoc false
  defstruct token: nil, data: nil, pid: nil, note: nil, profile: nil

  defimpl Enumerable, for: __MODULE__ do
    def reduce(changes, acc, fun) do
      stream = Stream.unfold(changes, fn
        x = %RethinkDB.Feed{data: []} ->
          r = RethinkDB.next(x)
          {r, struct(r, data: [])}
        x = %RethinkDB.Feed{} ->
          {x, struct(x, data: [])}
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
  @moduledoc false
  defstruct token: nil, data: "", profile: nil

  def parse(raw_data, token, pid) do
    d = Poison.decode!(raw_data)
    data = RethinkDB.Pseudotypes.convert_reql_pseudotypes(d["r"])
    resp = case d["t"] do
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
    %{resp | :profile => d["p"]}
  end
end

