defmodule Exrethinkdb.Record do
  defstruct data: ""
end

defmodule Exrethinkdb.Collection do
  defstruct data: []
end

defmodule Exrethinkdb.Cursor do
  defstruct token: nil, data: [], pid: nil
end

defmodule Exrethinkdb.Changes do
  defstruct token: nil, data: nil, pid: nil

  defimpl Enumerable, for: __MODULE__ do
    def reduce(changes, acc, fun) do
      stream = Stream.repeatedly(fn ->
        Exrethinkdb.next(changes)
      end) |> Stream.flat_map(fn (el) ->
        el.data
      end)
      stream.(acc, fun)
    end
  end
end

defmodule Exrethinkdb.Response do
  defstruct token: nil, data: ""

  def parse(raw_data, token, pid) do
    d = Poison.decode!(raw_data)
    case d["t"] do
      1  -> %Exrethinkdb.Record{data: hd(d["r"])}
      2  -> %Exrethinkdb.Collection{data: d["r"]}
      3  -> case d["n"] do
          [1] -> %Exrethinkdb.Changes{token: token, data: d["r"], pid: pid}
          [2] -> %Exrethinkdb.Changes{token: token, data: hd(d["r"]), pid: pid}
          _ -> %Exrethinkdb.Cursor{token: token, data: d["r"], pid: pid}
        end
      4  -> %Exrethinkdb.Response{token: token, data: d}
      16  -> %Exrethinkdb.Response{token: token, data: d}
      17  -> %Exrethinkdb.Response{token: token, data: d}
      18  -> %Exrethinkdb.Response{token: token, data: d}
    end
  end
end

