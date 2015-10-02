defmodule RethinkDB.Query.Macros do
  alias RethinkDB.Q
  alias RethinkDB.Query
  @moduledoc false

  defmacro operate_on_two_args(op, opcode) do
    quote do
      def unquote(op)(left, right, opts) when is_map(opts) do
        %Q{query: [unquote(opcode), [wrap(left), wrap(right)], opts]}
      end
      def unquote(op)(left, right) do
        %Q{query: [unquote(opcode), [wrap(left), wrap(right)]]}
      end
    end
  end
  defmacro operate_on_three_args(op, opcode) do
    quote do
      def unquote(op)(arg1, arg2, arg3, opts) when is_map(opts) do
        %Q{query: [unquote(opcode), [wrap(arg1), wrap(arg2), wrap(arg3)], opts]}
      end
      def unquote(op)(arg1, arg2, arg3) do
        %Q{query: [unquote(opcode), [wrap(arg1), wrap(arg2), wrap(arg3)]]}
      end
    end
  end
  defmacro operate_on_list(op, opcode) do
    quote do
      def unquote(op)(args) when is_list(args) do
        %Q{query: [unquote(opcode), Enum.map(args, &wrap/1)]}
      end
    end
  end
  defmacro operate_on_list_with_opts(op, opcode) do
    quote do
      def unquote(op)(args, opts) when is_list(args) and is_map(opts) do
        %Q{query: [unquote(opcode), Enum.map(args, &wrap/1), opts]}
      end
    end
  end
  defmacro operate_on_seq_and_list(op, opcode) do
    quote do
      def unquote(op)(seq, args, opts) when is_list(args) and is_map(opts) do
        %Q{query: [unquote(opcode), [wrap(seq) | Enum.map(args, &wrap/1)], opts]}
      end
      def unquote(op)(seq, args) when is_list(args) do
        %Q{query: [unquote(opcode), [wrap(seq) | Enum.map(args, &wrap/1)]]}
      end
    end
  end
  defmacro operate_on_single_arg(op, opcode) do
    quote do
      def unquote(op)(arg, opts) when is_map(opts) do
        %Q{query: [unquote(opcode), [wrap(arg)], opts]}
      end
      def unquote(op)(arg) do
        %Q{query: [unquote(opcode), [wrap(arg)]]}
      end
    end
  end
  
  defmacro operate_on_zero_args(op, opcode) do
    quote do
      def unquote(op)(), do: %Q{query: [unquote(opcode)]}
    end
  end

  def wrap(list) when is_list(list), do: Query.make_array(Enum.map(list, &wrap/1))
  def wrap(q = %Q{}), do: q
  def wrap(t = %RethinkDB.Pseudotypes.Time{}) do
    m = Map.from_struct(t) |> Map.put_new("$reql_type$", "TIME")
    wrap(m)
  end
  def wrap(map) when is_map(map) do
    Enum.map(map, fn {k,v} ->
      {k, wrap(v)}
    end) |> Enum.into(%{})
  end
  def wrap(f) when is_function(f), do: Query.func(f)
  def wrap(t) when is_tuple(t), do: wrap(Tuple.to_list(t))
  def wrap(data), do: data
end
