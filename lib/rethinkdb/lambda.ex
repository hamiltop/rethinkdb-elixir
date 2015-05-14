defmodule RethinkDB.Lambda do
  alias RethinkDB.Query
 
  defmacro lambda(block) do
    build(block)
  end

  defp build(block) do
    Macro.prewalk block, fn 
      {:+, _, args} ->      quote do: Query.MathLogic.add(unquote(args))
      {:<>, _, args} ->     quote do: Query.MathLogic.add(unquote(args))
      {:++, _, args} ->     quote do: Query.MathLogic.add(unquote(args))
      {:-, _, args} ->      quote do: Query.MathLogic.sub(unquote(args))
      {:*, _, args} ->      quote do: Query.MathLogic.mul(unquote(args))
      {:/, _, args} ->      quote do: Query.MathLogic.divide(unquote(args))
      {:rem, _, [a, b]} ->  quote do: Query.MathLogic.mod(unquote(a), unquote(b))
      {:==, _, args} ->     quote do: Query.MathLogic.eq(unquote(args))
      {:!=, _, args} ->     quote do: Query.MathLogic.ne(unquote(args))
      {:<, _, args} ->      quote do: Query.MathLogic.lt(unquote(args))
      {:<=, _, args} ->     quote do: Query.MathLogic.le(unquote(args))
      {:>, _, args} ->      quote do: Query.MathLogic.gt(unquote(args))
      {:>=, _, args} ->     quote do: Query.MathLogic.ge(unquote(args))
      {:||, _, args} ->     quote do: Query.MathLogic.or_r(unquote(args))
      {:&&, _, args} ->     quote do: Query.MathLogic.and_r(unquote(args))
      {:if, _, [expr, [do: truthy, else: falsy]]} ->
        quote do
          Query.ControlStructures.branch(unquote(expr), unquote(truthy), unquote(falsy))
        end
      x -> x
    end
  end

end
