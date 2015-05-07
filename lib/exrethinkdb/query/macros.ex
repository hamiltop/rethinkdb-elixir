defmodule Exrethinkdb.Query.Macros do
  alias Exrethinkdb.Query, as: Q
  @moduledoc false

  defmacro operate_on_two_args(op, opcode) do
    quote do
      def unquote(op)(left, right) do
        %Q{query: [unquote(opcode), [wrap(left), wrap(right)]]}
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
  defmacro operate_on_single_arg(op, opcode) do
    quote do
      def unquote(op)(arg) do
        %Q{query: [unquote(opcode), [arg]]}
      end
    end
  end
  defmacro operate_on_zero_args(op, opcode) do
    quote do
      def unquote(op)(), do: %Q{query: [unquote(opcode)]}
    end
  end

  def wrap(list) when is_list(list), do: Q.make_array(list)
  def wrap(data), do: data
end
