defmodule Exrethinkdb.Lambda do
  alias Exrethinkdb.Query
 
  defmacro lambda({:fn, _, [{:->, _, [h,t]}]}) do
    vars = h |> Enum.map(fn {var, _, _} -> var end) |> Enum.with_index
    build(t, vars)
  end
  defmacro lambda(block) do
    build(block, %{})
  end

  defp build(block, vars) do
    code = Macro.prewalk block, fn 
      {:+, _, args} -> Query.add(args)
      {:-, _, args} -> Query.sub(args)
      {:*, _, args} -> Query.mul(args)
      {:/, _, args} -> Query.div(args)
      {:rem, _, args} -> [28, args]
      {:., _, args} -> [170, args]
      {{:., _, args}, _, []} -> [170, args] # Weird case
      {var, _, nil} -> case Dict.get(vars, var) do
          nil -> raise "could not find #{inspect(var)}"
          x -> [10, [x]]
        end
      {x, _, _args} -> raise "#{inspect(x)} not supported"
      x -> x
    end
    quote do
      [69, [[2, unquote(Dict.values(vars))], unquote(code)]]
    end
  end
end
