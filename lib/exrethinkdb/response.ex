defmodule Exrethinkdb.Response do
  defstruct type: nil, token: nil, data: ""

  def parse(raw_data, token) do
    d = Poison.decode!(raw_data)
    type = case d["t"] do
      1  -> :success_atom
      2  -> :success_sequence
      3  -> :success_partial
      4  -> :wait_complete
      5  -> :success_feed
      16 -> :client_error
      17 -> :compile_error
    end
    %__MODULE__{type: type, token: token, data: d["r"]}   
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

