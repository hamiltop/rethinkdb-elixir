defmodule RethinkDB.Query.Geospatial do
  alias RethinkDB.Q
  @moduledoc """
  ReQL methods for aggregation operations.

  All examples assume that `use RethinkDB` has been called.
  """

  require RethinkDB.Query.Macros
  import RethinkDB.Query.Macros

  @doc """
  Construct a circular line or polygon. A circle in RethinkDB is a polygon or 
  line approximating a circle of a given radius around a given center, consisting 
  of a specified number of vertices (default 32).

  The center may be specified either by two floating point numbers, the latitude 
  (−90 to 90) and longitude (−180 to 180) of the point on a perfect sphere (see 
  Geospatial support for more information on ReQL’s coordinate system), or by a 
  point object. The radius is a floating point number whose units are meters by 
  default, although that may be changed with the unit argument.

  Optional arguments available with circle are:

  - num_vertices: the number of vertices in the polygon or line. Defaults to 32.
  - geo_system: the reference ellipsoid to use for geographic coordinates. Possible 
  values are WGS84 (the default), a common standard for Earth’s geometry, or 
  unit_sphere, a perfect sphere of 1 meter radius.
  - unit: Unit for the radius distance. Possible values are m (meter, the default), 
  km (kilometer), mi (international mile), nm (nautical mile), ft (international 
  foot).
  - fill: if `true` (the default) the circle is filled, creating a polygon; if `false` 
  the circle is unfilled (creating a line).
  """
  @spec circle(Q.reql_geo, Q.reql_number, Q.reql_opts) :: Q.t
  operate_on_two_args(:circle, 165)

  @doc """
  Compute the distance between a point and another geometry object. At least one 
  of the geometry objects specified must be a point.

  Optional arguments available with distance are:

  - geo_system: the reference ellipsoid to use for geographic coordinates. Possible 
  values are WGS84 (the default), a common standard for Earth’s geometry, or 
  unit_sphere, a perfect sphere of 1 meter radius.
  - unit: Unit to return the distance in. Possible values are m (meter, the 
  default), km (kilometer), mi (international mile), nm (nautical mile), ft 
  (international foot).

  If one of the objects is a polygon or a line, the point will be projected onto 
  the line or polygon assuming a perfect sphere model before the distance is 
  computed (using the model specified with geo_system). As a consequence, if the 
  polygon or line is extremely large compared to Earth’s radius and the distance 
  is being computed with the default WGS84 model, the results of distance should 
  be considered approximate due to the deviation between the ellipsoid and 
  spherical models.
  """
  @spec distance(Q.reql_geo, Q.reql_geo, Q.reql_opts) :: Q.t
  operate_on_two_args(:distance, 162)

  @spec fill(Q.reql_line) :: Q.t
  operate_on_single_arg(:fill, 167)

  @spec geojson(Q.reql_obj) :: Q.t
  operate_on_single_arg(:geojson, 157)

  @spec to_geojson(Q.reql_obj) :: Q.t
  operate_on_single_arg(:to_geojson, 158)

  @spec get_intersecting(Q.reql_array, Q.reql_geo, Q.reql_opts) :: Q.t
  operate_on_two_args(:get_intersecting, 166)

  @spec get_nearest(Q.reql_array, Q.reql_geo, Q.reql_opts) :: Q.t
  operate_on_two_args(:get_nearest, 168)

  @spec includes(Q.reql_geo, Q.reql_geo) :: Q.t
  operate_on_two_args(:includes, 164)

  @spec intersects(Q.reql_geo, Q.reql_geo) :: Q.t
  operate_on_two_args(:intersects, 165)

  @doc """
  Construct a geometry object of type Line. The line can be specified in one of 
  two ways:

  - Two or more two-item arrays, specifying latitude and longitude numbers of the 
  line’s vertices;
  - Two or more Point objects specifying the line’s vertices.
  """
  @spec line([Q.reql_geo]) :: Q.t
  operate_on_list(:line, 160)

  @doc """
  Construct a geometry object of type Point. The point is specified by two 
  floating point numbers, the longitude (−180 to 180) and latitude (−90 to 90) of 
  the point on a perfect sphere.
  """
  @spec point(Q.reql_geo) :: Q.t
  def point({la,lo}), do: point(la, lo)
  operate_on_two_args(:point, 159)

  @spec polygon([Q.reql_geo]) :: Q.t
  operate_on_list(:polygon, 161)

  @spec polygon_sub(Q.reql_geo, Q.reql_geo) :: Q.t
  operate_on_two_args(:polygon_sub, 171)
end
