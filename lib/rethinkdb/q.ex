defmodule RethinkDB.Q do
  @moduledoc false

  defstruct query: nil
end

defimpl Poison.Encoder, for: RethinkDB.Q do
  def encode(%{query: query}, options) do
    Poison.Encoder.encode(query, options)
  end
end

defimpl Inspect, for: RethinkDB.Q do
  @external_resource term_info = Path.join([__DIR__, "query", "term_info.json"])

  @apidef term_info
          |> File.read!()
          |> Poison.decode!()
          |> Enum.into(%{}, fn {key, val} -> {val, key} end)

  def inspect(%RethinkDB.Q{query: [69, [[2, refs], lambda]]}, _) do
    # Replaces references within lambda functions
    # with capture syntax arguments (&1, &2, etc).
    refs
    |> Enum.map_reduce(1, &{{&1, "&#{&2}"}, &2 + 1})
    |> elem(0)
    |> Enum.reduce("&(#{inspect(lambda)})", fn {ref, var}, lambda ->
      String.replace(lambda, "var(#{inspect(ref)})", var)
    end)
  end

  def inspect(%RethinkDB.Q{query: [index, args, opts]}, _) do
    # Converts function options (map) to keyword list.
    Kernel.inspect(%RethinkDB.Q{query: [index, args ++ [Map.to_list(opts)]]})
  end

  def inspect(%RethinkDB.Q{query: [index, args]}, _options) do
    # Resolve index & args and return them as string.
    Map.get(@apidef, index) <> "(#{Enum.join(Enum.map(args, &Kernel.inspect/1), ", ")})"
  end
end
