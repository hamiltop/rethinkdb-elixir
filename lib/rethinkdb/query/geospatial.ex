defmodule RethinkDB.Query.Geospatial do
  alias RethinkDB.Q
  @moduledoc """
  ReQL methods for aggregation operations.

  All examples assume that `use RethinkDB` has been called.
  """

  require RethinkDB.Query.Macros
  import RethinkDB.Query.Macros

  @spec circle(Q.reql_geo, Q.reql_number, Q.reql_opts) :: Q.t
  operate_on_two_args(:circle, 165)

  @spec distance(Q.reql_geo, Q.reql_geo, Q.reql_opts) :: Q.t
  operate_on_two_args(:distance, 162)

  @spec fill(Q.reql_geo) :: Q.t
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

  @spec line([Q.reql_geo]) :: Q.t
  operate_on_list(:line, 160)

  @spec point(Q.reql_geo) :: Q.t
  operate_on_single_arg(:point, 159)

  @spec point([Q.reql_geo]) :: Q.t
  operate_on_list(:polygon, 161)

  @spec polygon_sub(Q.reql_geo, Q.reql_geo) :: Q.t
  operate_on_two_args(:polygon_sub, 171)
end
