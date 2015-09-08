defmodule RethinkDB.Lambda do
  alias RethinkDB.Query
 
  defmacro lambda(block) do
    build(block)
  end

  defp build(block) do
    Macro.prewalk block, fn 
      {{:., _, [Access, :get]}, _, [arg1, arg2]} -> 
        quote do
          Query.bracket(unquote(arg1), unquote(arg2))
        end
      {:+, _, args} ->      quote do: Query.add(unquote(args))
      {:<>, _, args} ->     quote do: Query.add(unquote(args))
      {:++, _, args} ->     quote do: Query.add(unquote(args))
      {:-, _, args} ->      quote do: Query.sub(unquote(args))
      {:*, _, args} ->      quote do: Query.mul(unquote(args))
      {:/, _, args} ->      quote do: Query.divide(unquote(args))
      {:rem, _, [a, b]} ->  quote do: Query.mod(unquote(a), unquote(b))
      {:==, _, args} ->     quote do: Query.eq(unquote(args))
      {:!=, _, args} ->     quote do: Query.ne(unquote(args))
      {:<, _, args} ->      quote do: Query.lt(unquote(args))
      {:<=, _, args} ->     quote do: Query.le(unquote(args))
      {:>, _, args} ->      quote do: Query.gt(unquote(args))
      {:>=, _, args} ->     quote do: Query.ge(unquote(args))
      {:||, _, args} ->     quote do: Query.or_r(unquote(args))
      {:&&, _, args} ->     quote do: Query.and_r(unquote(args))
      {:if, _, [expr, [do: truthy, else: falsy]]} ->
        quote do
          Query.branch(unquote(expr), unquote(truthy), unquote(falsy))
        end
      x -> x
    end
  end

end
