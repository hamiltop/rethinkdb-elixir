defmodule RethinkDB.Pseudotypes do
  @moduledoc false
  defmodule Binary do
    @moduledoc false
    defstruct data: nil

    def parse(%{"$reql_type$" => "BINARY", "data" => data}, opts) do
      case Keyword.get(opts, :binary_format) do
        :raw ->
          %__MODULE__{data: data}

        _ ->
          :base64.decode(data)
      end
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
      defstruct coordinates: []
    end

    def parse(%{"$reql_type$" => "GEOMETRY", "coordinates" => [x, y], "type" => "Point"}) do
      %Point{coordinates: {x, y}}
    end

    def parse(%{"$reql_type$" => "GEOMETRY", "coordinates" => coords, "type" => "LineString"}) do
      %Line{coordinates: Enum.map(coords, &List.to_tuple/1)}
    end

    def parse(%{"$reql_type$" => "GEOMETRY", "coordinates" => coords, "type" => "Polygon"}) do
      %Polygon{coordinates: for(points <- coords, do: Enum.map(points, &List.to_tuple/1))}
    end
  end

  defmodule Time do
    @moduledoc false
    defstruct epoch_time: nil, timezone: nil

    def parse(
          %{"$reql_type$" => "TIME", "epoch_time" => epoch_time, "timezone" => timezone},
          opts
        ) do
      case Keyword.get(opts, :time_format) do
        :raw ->
          %__MODULE__{epoch_time: epoch_time, timezone: timezone}

        _ ->
          {seconds, ""} = Calendar.ISO.parse_offset(timezone)

          zone_abbr =
            case seconds do
              0 -> "UTC"
              _ -> timezone
            end

          negative = seconds < 0
          seconds = abs(seconds)

          time_zone =
            case {div(seconds, 3600), rem(seconds, 3600)} do
              {0, 0} ->
                "Etc/UTC"

              {hours, 0} ->
                "Etc/GMT" <>
                  if negative do
                    "+"
                  else
                    "-"
                  end <> Integer.to_string(hours)

              {hours, seconds} ->
                "Etc/GMT" <>
                  if negative do
                    "+"
                  else
                    "-"
                  end <>
                  Integer.to_string(hours) <>
                  ":" <> String.pad_leading(Integer.to_string(seconds), 2, "0")
            end

          (epoch_time * 1000)
          |> trunc()
          |> DateTime.from_unix!(:milliseconds)
          |> struct(utc_offset: seconds, zone_abbr: zone_abbr, time_zone: time_zone)
      end
    end
  end

  def convert_reql_pseudotypes(nil, _opts), do: nil

  def convert_reql_pseudotypes(%{"$reql_type$" => "BINARY"} = data, opts) do
    Binary.parse(data, opts)
  end

  def convert_reql_pseudotypes(%{"$reql_type$" => "GEOMETRY"} = data, _opts) do
    Geometry.parse(data)
  end

  def convert_reql_pseudotypes(%{"$reql_type$" => "GROUPED_DATA"} = data, _opts) do
    parse_grouped_data(data)
  end

  def convert_reql_pseudotypes(%{"$reql_type$" => "TIME"} = data, opts) do
    Time.parse(data, opts)
  end

  def convert_reql_pseudotypes(list, opts) when is_list(list) do
    Enum.map(list, fn data -> convert_reql_pseudotypes(data, opts) end)
  end

  def convert_reql_pseudotypes(map, opts) when is_map(map) do
    Enum.map(map, fn {k, v} ->
      {k, convert_reql_pseudotypes(v, opts)}
    end)
    |> Enum.into(%{})
  end

  def convert_reql_pseudotypes(string, _opts), do: string

  def parse_grouped_data(%{"$reql_type$" => "GROUPED_DATA", "data" => data}) do
    Enum.map(data, fn [k, data] ->
      {k, data}
    end)
    |> Enum.into(%{})
  end

  def create_grouped_data(data) when is_map(data) do
    data = data |> Enum.map(fn {k, v} -> [k, v] end)
    %{"$reql_type$" => "GROUPED_DATA", "data" => data}
  end
end
