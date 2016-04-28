defmodule RethinkDB.Q do
  @moduledoc false

  @derive [Poison.Encoder]

  defstruct query: nil, message: nil

  defimpl DBConnection.Query do
    import RethinkDB.Prepare, only: [prepare: 1]
    import RethinkDB.Response, only: [parse: 3]

    def parse(query, _options), do: query

    def describe(query, options) do
      # Prepares the query with the given options.
      options = Keyword.take(options, ~w(database timeout durability profile noreply)a)
      options = Enum.into(options, %{}, fn
        {:database, db} ->
          {:db, prepare(RethinkDB.Query.db(db))}
        {k, v} ->
          {k, v}
      end)

      # Formats the query and serializes it to JSON.
      message = [1, prepare(query), options]
      |> Poison.encode!()

      %{query | message: message}
    end

    def encode(query, _params, _options), do: query

    def decode(_query, _result, noreply: true), do: :ok

    def decode(_query, {token, data, pid}, _options) do
      parse(data, token, pid)
    end

    def decode(_query, _result, _options) do
      %RethinkDB.Response{}
    end

  end
end
