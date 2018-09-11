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
    def slice(%{data: data}), do: Enumerable.slice(data)
  end
end

defmodule RethinkDB.Feed do
  @moduledoc false
  defstruct token: nil, data: nil, pid: nil, note: nil, profile: nil, opts: nil

  defimpl Enumerable, for: __MODULE__ do
    def reduce(changes, acc, fun) do
      stream =
        Stream.unfold(changes, fn
          x = %RethinkDB.Feed{data: []} ->
            {:ok, r} = RethinkDB.next(x)
            {r, struct(r, data: [])}

          x = %RethinkDB.Feed{} ->
            {x, struct(x, data: [])}

          x = %RethinkDB.Collection{} ->
            {x, nil}

          nil ->
            nil
        end)
        |> Stream.flat_map(fn el ->
          el.data
        end)

      stream.(acc, fun)
    end

    def count(_changes), do: raise("count/1 not supported for changes")
    def member?(_changes, _values), do: raise("member/2 not supported for changes")
    def slice(_changes), do: raise("slice/1 is not supported for changes")
  end
end

defmodule RethinkDB.Response do
  @moduledoc false
  defstruct token: nil, data: "", profile: nil

  def parse(raw_data, token, pid, opts) do
    d = Poison.decode!(raw_data)
    data = RethinkDB.Pseudotypes.convert_reql_pseudotypes(d["r"], opts)

    {code, resp} =
      case d["t"] do
        1 -> {:ok, %RethinkDB.Record{data: hd(data)}}
        2 -> {:ok, %RethinkDB.Collection{data: data}}
        3 -> {:ok, %RethinkDB.Feed{token: token, data: data, pid: pid, note: d["n"], opts: opts}}
        4 -> {:ok, %RethinkDB.Response{token: token, data: d}}
        16 -> {:error, %RethinkDB.Response{token: token, data: d}}
        17 -> {:error, %RethinkDB.Response{token: token, data: d}}
        18 -> {:error, %RethinkDB.Response{token: token, data: d}}
      end

    {code, %{resp | :profile => d["p"]}}
  end
end
