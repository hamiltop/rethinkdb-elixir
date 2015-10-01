defmodule RethinkDB.Changefeed do
  use Behaviour

  use GenServer

  require Logger

  defmacro __using__(_opts) do
    quote do
      @behaviour RethinkDB.Changefeed
    end
  end

  # return {:subscribe, query, db, state}
  # return {:stop, reason} 
  defcallback init(opts :: any) :: any
  #defcallback handle_data(data :: any, state)
  defcallback handle_update(update :: any, state :: any) :: any

  def start_link(mod, query, conn, args, opts) do
    GenServer.start_link(__MODULE__,
      [mod: mod, args: args, query: query, conn: conn],
      opts)
  end

  def init(opts) do
    mod = Dict.get(opts, :mod)
    args = Dict.get(opts, :args)
    query = Dict.get(opts, :query)
    conn = Dict.get(opts, :conn)
    feed_state = case mod.init(args) do
      {:ok, state} -> state
    end
    run_task = run(query, conn)
    {:ok, %{feed_state: feed_state, opts: opts, run: run_task}}
  end

  def handle_info({:DOWN, ref, _, _, _}, state) do
    run_ref = state[:run] && state[:run].ref
    next_ref = state[:next] && state[:next].ref
    case ref do
      ^run_ref  -> :ok
      ^next_ref -> :ok
      _ -> :ok
    end
    {:noreply, state}
  end

  def handle_info({ref, msg}, state) when is_reference(ref) do
    run_ref = state[:run] && state[:run].ref
    next_ref = state[:next] && state[:next].ref
    mod = get_in(state, [:opts, :mod])
    feed_state = Dict.get(state, :feed_state)
    # TODO: resolve race condition around :DOWN events
    new_state = case ref do
      ^run_ref  ->
        #mod.handle_data(msg, feed_state) 
        Dict.put(state, :next, next(msg))
      ^next_ref ->
        mod.handle_update(msg.data, feed_state) 
        Dict.put(state, :next, next(msg))
    end
    {:noreply, new_state}
  end

  def handle_info({:update, data}, s = %{feed_state: feed_state, mod: mod} ) do
    resp = mod.handle_update(data, feed_state)
    Logger.debug("Got #{inspect resp} from handle_update")
    {:noreply, s}
  end

  defp run(q,c) do
    Task.async fn ->
      RethinkDB.run(q,c)
    end
  end

  defp next(f = %RethinkDB.Feed{}) do
    Task.async fn ->
      RethinkDB.next(f)
    end
  end
end
