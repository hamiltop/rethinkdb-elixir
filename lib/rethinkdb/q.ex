defmodule RethinkDB.Q do
  defstruct query: nil
end
defimpl Poison.Encoder, for: RethinkDB.Q do
  def encode(%{query: query}, options) do
    Poison.Encoder.encode(query, options)
  end
end
defimpl Access, for: RethinkDB.Q do
  def get(%{query: query}, term) do
    RethinkDB.Query.bracket(query, term)
  end
  def get_and_update(_,_,_), do: raise "get_and_update not supported"
end
