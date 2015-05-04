defmodule Exrethinkdb.Query.StringManipulation do
  alias Exrethinkdb.Query, as: Q
  @moduledoc """
  ReQL methods for string manipulation.

  All examples assume that `use Exrethinkdb` has been called.
  """

  @doc """
  Checks a string for matches. 

  Example:

      iex> "hello world" |> match("hello") |> run
      iex> "hello world" |> match(~r(hello)) |> run

  """
  @spec match( (Q.reql_string), (Regex.t|Q.reql_string) ) :: Q.t
  def match(string_a, regex = %Regex{}), do: match(string_a, Regex.source(regex))
  def match(string_a, string_b), do: %Q{query: [97, [string_a, string_b]]}

  @doc """
  Split a `string` with a given `separator`.
  
  Default `separator  is whitespace.

  If a `max_results` is not included, return all results.

      iex> "abracadabra" |> split |> run
      %Exrethinkdb.Record{data: ["abracadabra"]}
      iex> "abra-cadabra" |> split("-") |> run
      %Exrethinkdb.Record{data: ["abra", "cadabra"]}
      iex> "a-bra-ca-da-bra" |> split("-", 2) |> run
      %Exrethinkdb.Record{data: ["a", "bra", "ca-da-bra"]}
  
  """
  @spec split(Q.reql_string) :: Q.t
  @spec split(Q.reql_string, Q.reql_string) :: Q.t
  @spec split(Q.reql_string, (Q.reql_string|nil), integer) :: Q.t
  def split(string, separator, max_results), do: %Q{query: [149, [string, separator, max_results]]}
  def split(string), do: %Q{query: [149, [string]]}
  def split(string, separator), do: %Q{query: [149, [string, separator]]}

  @doc """
  Convert a string to all upper case.

      iex> "hi" |> upcase |> run
      %Exrethinkdb.Record{data: "HI"}

  """
  @spec upcase(Q.reql_string) :: Q.t
  def upcase(string), do: %Q{query: [141, [string]]}

  @doc """
  Convert a string to all down case.

      iex> "Hi" |> downcase |> run
      %Exrethinkdb.Record{data: "hi"}

  """
  @spec downcase(Q.reql_string) :: Q.t
  def downcase(string), do: %Q{query: [142, [string]]}
end
