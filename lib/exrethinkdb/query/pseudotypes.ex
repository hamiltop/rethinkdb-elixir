defmodule Exrethinkdb.Query.Pseudotypes do

  def convert_reql_pseudotypes(nil), do: nil
  def convert_reql_pseudotypes(%{"$reql_type$" => "GROUPED_DATA"} = data) do
    parse_grouped_data(data)
  end
  def convert_reql_pseudotypes(list) when is_list(list) do
    Enum.map(list, &convert_reql_pseudotypes/1)
  end
  def convert_reql_pseudotypes(map) when is_map(map) do
    Enum.map(map, fn {k, v} ->
      {k, convert_reql_pseudotypes(v)}
    end) |> Enum.into %{}
  end
  def convert_reql_pseudotypes(string), do: string

  def parse_grouped_data(%{"$reql_type$" => "GROUPED_DATA", "data" => data}) do
    Enum.map(data, fn ([k, data]) ->
      {k, data}
    end) |> Enum.into(%{})
  end
  def create_grouped_data(data) when is_map(data) do
    data = data |> Enum.map fn {k,v} -> [k, v] end
    %{"$reql_type$" => "GROUPED_DATA", "data" => data}
  end
end
