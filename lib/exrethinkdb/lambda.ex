defmodule Exrethinkdb.Lambda do
  alias Exrethinkdb.Query
 
  defmacro lambda(block) do
    build(block)
  end

  defp build(block) do
    Macro.prewalk block, fn 
      {:+, _, args} ->      quote do: Query.add(unquote(args))
      {:-, _, args} ->      quote do: Query.sub(unquote(args))
      {:*, _, args} ->      quote do: Query.mul(unquote(args))
      {:/, _, args} ->      quote do: Query.div(unquote(args))
      {:rem, _, [a, b]} ->  quote do: Query.mod(unquote(a), unquote(b))
      {:==, _, args} ->     quote do: Query.eq(unquote(args))
      {:!=, _, args} ->     quote do: Query.ne(unquote(args))
      {:<, _, args} ->      quote do: Query.lt(unquote(args))
      {:<=, _, args} ->     quote do: Query.le(unquote(args))
      {:>, _, args} ->      quote do: Query.gt(unquote(args))
      {:>=, _, args} ->     quote do: Query.ge(unquote(args))
      x -> x
    end
  end

end
