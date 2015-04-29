defmodule Exrethinkdb.Lambda do
  alias Exrethinkdb.Query
 
  defmacro lambda(block) do
    build(block)
  end

  defp build(block) do
    Macro.prewalk block, fn 
      {:+, _, args} -> Query.add(args)
      {:-, _, args} -> Query.sub(args)
      {:*, _, args} -> Query.mul(args)
      {:/, _, args} -> Query.div(args)
      {:rem, _, [a, b]} -> Query.mod(a, b)
      {:=, _, args} -> Query.eq(args)
      {:!=, _, args} -> Query.ne(args)
      {:<, _, args} -> Query.lt(args)
      {:<=, _, args} -> Query.le(args)
      {:>, _, args} -> Query.gt(args)
      {:>=, _, args} -> Query.ge(args)
      x -> x
    end
  end

end
