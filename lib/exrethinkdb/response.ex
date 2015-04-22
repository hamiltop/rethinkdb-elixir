defmodule Exrethinkdb.Response do
  defmodule Single do
    defstruct data: ""
  end

  defmodule Collection do
    defstruct data: []
  end

  defmodule Cursor do
    defstruct token: nil, data: []
  end

  defmodule Changes do
    defstruct token: nil, last: nil
  end

  defmodule Response do
    defstruct token: nil, raw: ""
  end

  def parse(raw_data, token) do
    d = Poison.decode!(raw_data)
    case d["t"] do
      1  -> %Single{data: hd(d["r"])}
      2  -> %Collection{data: d["r"]}
      3  -> case d["n"] do
          [1] -> %Changes{token: token, last: nil}
          [2] -> %Changes{token: token, last: hd(d["r"])}
          _ -> %Cursor{token: token, data: d["r"]}
        end
      4  -> %Response{token: token, raw: d}
      5  -> %Changes{token: token, last: d["r"]}
      16  -> %Response{token: token, raw: d}
      17  -> %Response{token: token, raw: d}
    end
  end

  defimpl Inspect, for: __MODULE__ do
    import Inspect.Algebra

    def inspect(response, opts) do
      data = case response.type do
        b when b in [:success_partial, :success_feed] -> :cursor
        x -> x
      end
      concat ["#Response<", to_doc(data, opts), ">"]
    end
  end

  defimpl Enumerable, for: __MODULE__ do
    def reduce(%{data: data}, acc, fun) when is_list(data), do: Enumerable.reduce(data, acc, fun)

    def count(%{data: data}) when is_list(data), do: Enumerable.count(data)

    def member?(%{data: data}, v) when is_list(data), do: Enumerable.member?(data, v)
  end
end

