defmodule Exrethinkdb.Lambda do
 
  defmacro lambda({:fn, _, [{:->, _, [h,t]}]}) do
    vars = h |> Enum.map(fn {var, _, _} -> var end) |> Enum.with_index
    build(t, vars)
  end
  defmacro lambda(block) do
    build(block, %{})
  end

  defp build(block, vars) do
    code = Macro.prewalk block, fn 
      {:+, _, args} -> [24, args]
      {:-, _, args} -> [25, args]
      {:*, _, args} -> [26, args]
      {:/, _, args} -> [27, args]
      {:rem, _, args} -> [28, args]
      {:., _, args} -> [170, args]
      {{:., _, args}, _, []} -> [170, args] # Weird case
      {var, _, nil} -> case Dict.get(vars, var) do
          nil -> raise "could not find #{inspect(var)}"
          x -> [10, [x]]
        end
      {x, _, args} -> raise "#{inspect(x)} not supported"
      x -> x
    end
    [69, [[2, Dict.values(vars)], code]]
  end
end
