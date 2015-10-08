defmodule RethinkDB.Changefeed do
  use Behaviour

  use Connection

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

  defdelegate call(server, request, timeout), to: Connection 
  defdelegate call(server, request), to: Connection
  defdelegate cast(server, request), to: Connection

  def start_link(mod, args, opts) do
    Connection.start_link(__MODULE__,
      [mod: mod, args: args],
      opts)
  end

  def init(opts) do
    mod = Dict.get(opts, :mod)
    args = Dict.get(opts, :args)
    {:subscribe, query, conn, feed_state} = mod.init(args)
    state = %{
      query: query,
      conn: conn,
      feed_state: feed_state,
      opts: opts,
      state: :connect
    }
    {:connect, :init, state}
  end

  def connect(_info, state = %{query: query, conn: conn}) do
    case RethinkDB.run(query, conn) do
      msg = %RethinkDB.Feed{} ->
        mod = get_in(state, [:opts, :mod])
        feed_state = Dict.get(state, :feed_state)
        {:ok, feed_state} = mod.handle_data(msg.data, feed_state)
        new_state = state
          |> Dict.put(:task, next(msg))
          |> Dict.put(:last, msg)
          |> Dict.put(:feed_state, feed_state)
          |> Dict.put(:state, :next)
        {:ok, new_state}
      _ ->
        backoff = min(Dict.get(state, :timeout, 1000), 64000)
        {:backoff, backoff, Dict.put(state, :timeout, backoff*2)}
    end
  end

  def disconnect(_info, state = %{last: msg}) do
    RethinkDB.Connection.close(msg)
    {:stop, :normal, state}
  end

  def handle_call(msg, from, state) do
    mod = get_in(state, [:opts, :mod])
    feed_state = Dict.get(state, :feed_state)
    case mod.handle_call(msg, from, feed_state) do
      {:reply, reply, new_feed_state} ->
        new_state = Dict.put(state, :feed_state, new_feed_state)
        {:reply, reply, new_state}
      {:reply, reply, new_feed_state, timeout} ->
        new_state = Dict.put(state, :feed_state, new_feed_state)
        {:reply, reply, new_state, timeout}
      {:noreply, new_feed_state} ->
        new_state = Dict.put(state, :feed_state, new_feed_state)
        {:noreply, new_state}
      {:noreply, new_feed_state, timeout} ->
        new_state = Dict.put(state, :feed_state, new_feed_state)
        {:noreply, new_state, timeout}
      {:stop, reason, reply, new_feed_state} ->
        new_state = Dict.put(state, :feed_state, new_feed_state)
        {:stop, reason, reply, new_state}
      {:stop, reason, new_feed_state} ->
        new_state = Dict.put(state, :feed_state, new_feed_state)
        {:stop, reason, new_state}
    end
  end

  def handle_cast(msg, state) do
    mod = get_in(state, [:opts, :mod])
    feed_state = Dict.get(state, :feed_state)
    case mod.handle_cast(msg, feed_state) do
      {:noreply, new_feed_state} ->
        new_state = Dict.put(state, :feed_state, new_feed_state)
        {:noreply, new_state}
      {:noreply, new_feed_state, timeout} ->
        new_state = Dict.put(state, :feed_state, new_feed_state)
        {:noreply, new_state, timeout}
      {:stop, reason, new_feed_state} ->
        new_state = Dict.put(state, :feed_state, new_feed_state)
        {:stop, reason, new_state}
    end
  end

  # TODO: handle_info pass through to callback. Look at Connection to see how they deal with it.

  def handle_info({ref, msg}, state = %{state: :next, task: %Task{ref: ref}}) do
    Process.demonitor(ref, [:flush])
    case msg do
      %RethinkDB.Feed{data: data} ->
        mod = get_in(state, [:opts, :mod])
        feed_state = Dict.get(state, :feed_state)
        {:ok, feed_state} = mod.handle_update(data, feed_state)
        new_state = state
          |> Dict.put(:task, next(msg))
          |> Dict.put(:feed_state, feed_state)
          |> Dict.put(:last, msg)
        {:noreply, new_state}
      _ ->
        {:stop, :rethinkdb_error, state}
    end
  end

  def handle_info(msg, state) do
    Logger.debug("Unhandled info: #{inspect msg}")
    {:noreply, state}
  end

  defp next(f = %RethinkDB.Feed{}) do
    Task.async fn ->
      RethinkDB.next(f)
    end
  end
end
