defmodule RethinkDB.Q do
  @moduledoc false
  defstruct query: nil
end
defimpl Poison.Encoder, for: RethinkDB.Q do
  def encode(%{query: query}, options) do
    Poison.Encoder.encode(query, options)
  end
end
