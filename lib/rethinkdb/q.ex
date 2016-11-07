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

  @apidef File.read!(term_info)
          |> Poison.decode!()
          |> Enum.into(%{}, fn {key, val} -> {val["id"], String.downcase(key)} end)

  def inspect(%RethinkDB.Q{query: [index, params]}, _) do
    query =
      # Replaces references with a-z variable names,
      # using the same ref between fn head and body.
      params
      |> Enum.map_reduce(97, &resolve_param/2)
      |> elem(0)
      |> Enum.join(", ")
    "#{Map.get(@apidef, index, index)}(#{query})"
  end

  defp resolve_param([2, [ref]], acc) when is_reference(ref) do
    # function head reference
    {to_string([acc]), acc + 1}
  end

  defp resolve_param(ref, acc) when is_reference(ref) do
    # function body reference
    {to_string([acc]), acc + 1}
  end

  defp resolve_param(val, acc) do
    {Kernel.inspect(val), acc}
  end
end
