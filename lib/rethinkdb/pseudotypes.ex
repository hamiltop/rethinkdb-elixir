defmodule RethinkDB.Pseudotypes do
  @moduledoc false
  defmodule Binary do
    @moduledoc false
    defstruct data: nil

    def parse(%{"$reql_type$" => "BINARY", "data" => data}) do
      %__MODULE__{data: :base64.decode(data)}
    end
  end

  defmodule Geometry do
    @moduledoc false
    defmodule Point do
      @moduledoc false
      defstruct coordinates: []
    end

    defmodule Line do
      @moduledoc false
      defstruct coordinates: []
    end

    defmodule Polygon do
      @moduledoc false
      defstruct outer_coordinates: [], inner_coordinates: []
    end

    def parse(%{"$reql_type$" => "GEOMETRY", "coordinates" => [x,y], "type" => "Point"}) do
      %Point{coordinates: {x,y}}
    end
    def parse(%{"$reql_type$" => "GEOMETRY", "coordinates" => coords, "type" => "LineString"}) do
      %Line{coordinates: Enum.map(coords, &List.to_tuple/1)}
    end
    def parse(%{"$reql_type$" => "GEOMETRY", "coordinates" => coords, "type" => "Polygon"}) do
      {outer, inner} = case coords do
        [outer, inner] -> {Enum.map(outer, &List.to_tuple/1), Enum.map(inner, &List.to_tuple/1)}
        [outer | []] -> {Enum.map(outer, &List.to_tuple/1), []}
      end
      %Polygon{outer_coordinates: outer, inner_coordinates: inner}
    end
  end

  defmodule Time do
    @moduledoc false
    defstruct epoch_time: nil, timezone: nil

    def parse(%{"$reql_type$" => "TIME", "epoch_time" => epoch_time, "timezone" => timezone}) do
      %__MODULE__{epoch_time: epoch_time, timezone: timezone}
    end
  end

  def convert_reql_pseudotypes(nil), do: nil
  def convert_reql_pseudotypes(%{"$reql_type$" => "BINARY"} = data) do
    Binary.parse(data)
  end
  def convert_reql_pseudotypes(%{"$reql_type$" => "GEOMETRY"} = data) do
    Geometry.parse(data)
  end
  def convert_reql_pseudotypes(%{"$reql_type$" => "GROUPED_DATA"} = data) do
    parse_grouped_data(data)
  end
  def convert_reql_pseudotypes(%{"$reql_type$" => "TIME"} = data) do
    Time.parse(data)
  end
  def convert_reql_pseudotypes(list) when is_list(list) do
    Enum.map(list, &convert_reql_pseudotypes/1)
  end
  def convert_reql_pseudotypes(map) when is_map(map) do
    Enum.map(map, fn {k, v} ->
      {k, convert_reql_pseudotypes(v)}
    end) |> Enum.into(%{})
  end
  def convert_reql_pseudotypes(string), do: string

  def parse_grouped_data(%{"$reql_type$" => "GROUPED_DATA", "data" => data}) do
    Enum.map(data, fn ([k, data]) ->
      {k, data}
    end) |> Enum.into(%{})
  end
  def create_grouped_data(data) when is_map(data) do
    data = data |> Enum.map(fn {k,v} -> [k, v] end)
    %{"$reql_type$" => "GROUPED_DATA", "data" => data}
  end
end
