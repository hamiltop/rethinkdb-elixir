defmodule RethinkDB.Query.StringManipulation do
  alias RethinkDB.Q
  @moduledoc """
  ReQL methods for string manipulation.

  All examples assume that `use RethinkDB` has been called.
  """

  @doc """
  Checks a string for matches. 

  Example:

      iex> "hello world" |> match("hello") |> run conn
      iex> "hello world" |> match(~r(hello)) |> run conn

  """
  @spec match( (Q.reql_string), (Regex.t|Q.reql_string) ) :: Q.t
  def match(string, regex = %Regex{}), do: match(string, Regex.source(regex))
  def match(string, match_string), do: %Q{query: [97, [string, match_string]]}

  @doc """
  Split a `string` on whitespace.

      iex> "abracadabra" |> split |> run conn
      %RethinkDB.Record{data: ["abracadabra"]}
  """
  @spec split(Q.reql_string) :: Q.t
  def split(string), do: %Q{query: [149, [string]]}

  @doc """
  Split a `string` on `separator`.

      iex> "abra-cadabra" |> split("-") |> run conn
      %RethinkDB.Record{data: ["abra", "cadabra"]}
  """
  @spec split(Q.reql_string, Q.reql_string) :: Q.t
  def split(string, separator), do: %Q{query: [149, [string, separator]]}

  @doc """
  Split a `string` with a given `separator` into `max_result` segments.
  
      iex> "a-bra-ca-da-bra" |> split("-", 2) |> run conn
      %RethinkDB.Record{data: ["a", "bra", "ca-da-bra"]}
  
  """
  @spec split(Q.reql_string, (Q.reql_string|nil), integer) :: Q.t
  def split(string, separator, max_results), do: %Q{query: [149, [string, separator, max_results]]}

  @doc """
  Convert a string to all upper case.

      iex> "hi" |> upcase |> run conn
      %RethinkDB.Record{data: "HI"}

  """
  @spec upcase(Q.reql_string) :: Q.t
  def upcase(string), do: %Q{query: [141, [string]]}

  @doc """
  Convert a string to all down case.

      iex> "Hi" |> downcase |> run conn
      %RethinkDB.Record{data: "hi"}

  """
  @spec downcase(Q.reql_string) :: Q.t
  def downcase(string), do: %Q{query: [142, [string]]}
end
