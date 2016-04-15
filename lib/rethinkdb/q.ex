defmodule RethinkDB.Q do
  @moduledoc false

  @derive [Poison.Encoder]

  defstruct query: nil, message: nil

  defimpl DBConnection.Query do
    import RethinkDB.Prepare, only: [prepare: 1]
    import RethinkDB.Response, only: [parse: 3]

    def parse(query, _options), do: query

    def describe(query, options) do
      options = Keyword.take(options, ~w(database timeout durability profile noreply)a)
      options = Enum.into(options, %{}, fn
        {:database, db} ->
          {:db, prepare(RethinkDB.Query.db(db))}
        {k, v} ->
          {k, v}
      end)

      message = [1, prepare(query), options]
      |> Poison.encode!()

      %{query | message: message}
    end

    def encode(query, _params, _options), do: query

    def decode(_query, _result, noreply: true), do: :ok

    def decode(_query, {data, token, sock}, _options) do
      parse(data, token, Port.info(sock)[:connected])
    end

    def decode(_query, _result, _options) do
      %RethinkDB.Response{}
    end

  end
end
