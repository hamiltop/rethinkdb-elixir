defmodule Exrethinkdb.Connection.Pool do
  use Supervisor

  defmacro __using__(_opts) do
    quote do
      defmacro __using__(_opts) do
        use Exrethinkdb.Query
        import unquote(__MODULE__)
      end
      def start_link(opts \\ []) do
        opts = Dict.put_new(opts, :name, __MODULE__)
        a = Agent.start_link(fn -> 0 end, name: __MODULE__.Agent)
        Exrethinkdb.Connection.Pool.start_link(opts)  
      end
      def run(query) do
        n = Agent.get_and_update(__MODULE__.Agent, fn (count) ->
          {count, count + 1}
        end)
        conn = Exrethinkdb.Connection.Pool.get_connection(__MODULE__, n)
        Exrethinkdb.Connection.run(query, conn)
      end
      
      defdelegate next(query), to: Exrethinkdb.Connection
    end
  end

  def start_link(opts \\ []) do
    hosts = Dict.get(opts, :hosts) 
    Supervisor.start_link(__MODULE__, hosts, opts)
  end

  def init(hosts) do
    children = hosts
      |> Stream.with_index |> Enum.map fn ({host, id}) ->
        worker(Exrethinkdb.Connection, [host], id: id)
      end

    supervise(children, strategy: :one_for_one)
  end
  
  def run(query, pid) do
    Exrethinkdb.Connection.run query, get_connection(pid)
  end

  def get_connection(pid, n \\ 0) do
    connections = Supervisor.which_children(pid) |>
      Stream.map(fn
        {_id, :restarting, _type, _modules} -> nil
        {_id, :undefined, _type, _modules} -> nil
        {_id, child, _type, _modules} -> child   
      end) |> Stream.filter(&(&1 != nil)) |> Enum.to_list
    conn_length = Enum.count(connections)
    n = rem(n, conn_length)
    Enum.at(connections, n)
  end
end
