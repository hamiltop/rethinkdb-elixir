defmodule Exrethinkdb.Record do
  defstruct data: ""
end

defmodule Exrethinkdb.Collection do
  defstruct data: []
end

defmodule Exrethinkdb.Cursor do
  defstruct token: nil, data: []
end

defmodule Exrethinkdb.Changes do
  defstruct token: nil, data: nil
end

defmodule Exrethinkdb.Response do
  defstruct token: nil, data: ""

  def parse(raw_data, token) do
    d = Poison.decode!(raw_data)
    case d["t"] do
      1  -> %Exrethinkdb.Record{data: hd(d["r"])}
      2  -> %Exrethinkdb.Collection{data: d["r"]}
      3  -> case d["n"] do
          [1] -> %Exrethinkdb.Changes{token: token, data: nil}
          [2] -> %Exrethinkdb.Changes{token: token, data: hd(d["r"])}
          _ -> %Exrethinkdb.Cursor{token: token, data: d["r"]}
        end
      4  -> %Exrethinkdb.Response{token: token, data: d}
      16  -> %Exrethinkdb.Response{token: token, data: d}
      17  -> %Exrethinkdb.Response{token: token, data: d}
      18  -> %Exrethinkdb.Response{token: token, data: d}
    end
  end
end

