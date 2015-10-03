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
  # return {:ok, state}
  # return {:stop, reason, state}
  defcallback handle_data(data :: any, state :: any) :: any
  # return {:ok, state}
  # return {:stop, reason, state}
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
    {:ok, %{feed_state: feed_state, opts: opts, state: :run, task: run_task}}
  end

  def handle_info({ref, msg}, state = %{state: :next, task: %Task{ref: ref}}) do
    Process.demonitor(ref, [:flush])
    mod = get_in(state, [:opts, :mod])
    feed_state = Dict.get(state, :feed_state)
    mod.handle_update(msg.data, feed_state)
    {:noreply, Dict.put(state, :task, next(msg))}
  end

  def handle_info({ref, msg}, state = %{state: :run, task: %Task{ref: ref}}) do
    Process.demonitor(ref, [:flush])
    mod = get_in(state, [:opts, :mod])
    feed_state = Dict.get(state, :feed_state)
    mod.handle_data(msg.data, feed_state) 
    new_state = state
      |> Dict.put(:task, next(msg))
      |> Dict.put(:state, :next)
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
