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
    def count(_changes), do: raise "count/1 not supported for changes"
    def member?(_changes, _values), do: raise "member/2 not supported for changes"
  end
end

defmodule Exrethinkdb.Response do
  defstruct token: nil, data: ""

  def parse(raw_data, token, pid) do
    rt = Exrethinkdb.Ql2.Response.ResponseType |> Map.from_struct |> Map.to_list
    d = Poison.decode!(raw_data)
    case :lists.keyfind(d["t"],2,rt) do

      {:SUCCESS_ATOM, 1}  -> %Exrethinkdb.Record{data: hd(d["r"])}
      {:SUCCESS_SEQUENCE, 2} -> %Exrethinkdb.Collection{data: d["r"]}
      {:SUCCESS_PARTIAL, 3}  -> case :lists.keyfind(d["n"],2,rt) do
                                    {:SUCCESS_ATOM, 1} ->
                                    %Exrethinkdb.Changes{token: token, data: d["r"], pid: pid}
                                    {:SUCCESS_SEQUENCE, 2} ->
                                    %Exrethinkdb.Changes{token: token, data: hd(d["r"]), pid: pid}
                                    _ -> %Exrethinkdb.Cursor{token: token, data: d["r"], pid: pid}
                                end

        {:WAIT_COMPLETE, 4}  -> %Exrethinkdb.Response{token: token, data: d}
        {:RUNTIME_ERROR, 18}    -> raise Exrethinkdb.RqlRuntimeError, message: d["r"] |> hd
        {:COMPILE_ERROR, 17}    -> raise Exrethinkdb.RqlCompileError,message: d["r"] |> hd
        {:CLIENT_ERROR, 16}     -> raise Exrethinkdb.RqlDriverError, message: d["r"] |> hd
    end
  end




end

