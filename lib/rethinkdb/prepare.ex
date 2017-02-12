defmodule RethinkDB.Prepare do
  alias RethinkDB.Q
  @moduledoc false

  # This is a bunch of functions that transform the query from our data structures into
  # the over the wire format. The main role is to properly create unique function variable ids.

  def prepare(query) do
    {val, _vars} = prepare(query, {0, %{}})
    val
  end
  defp prepare(%Q{query: query}, state) do
    prepare(query, state)
  end
  defp prepare(list, state) when is_list(list) do
    {list, state} = Enum.reduce(list, {[], state}, fn (el, {acc, state}) ->
      {el, state} = prepare(el, state)
      {[el | acc], state}
    end)
    {Enum.reverse(list), state}
  end
  defp prepare(map, state) when is_map(map) do
    {map, state} = Enum.reduce(map, {[], state}, fn({k,v}, {acc, state}) ->
      {k, state} = prepare(k, state)
      {v, state} = prepare(v, state)
      {[{k, v} | acc], state}
    end)
    {Enum.into(map, %{}), state}
  end
  defp prepare(ref, state = {max, map}) when is_reference(ref) do
    case Map.get(map, ref) do
      nil -> {max + 1, {max + 1, Map.put_new(map, ref, max + 1)}}
      x   -> {x, state}
    end
  end
  defp prepare({k, v}, state) do
    {k, state} = prepare(k, state)
    {v, state} = prepare(v, state)
    {[k, v], state}
  end
  defp prepare(el, state) do
    {el, state}
  end
end
