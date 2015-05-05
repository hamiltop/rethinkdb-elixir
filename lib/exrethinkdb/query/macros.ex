defmodule Exrethinkdb.Query.Macros do
  alias Exrethinkdb.Query, as: Q
  @moduledoc false

  defmacro operate_on_two_args(op, opcode) do
    quote do
      def unquote(op)(numA, numB) do
        %Q{query: [unquote(opcode), [wrap(numA), wrap(numB)]]}
      end
    end
  end
  defmacro operate_on_list(op, opcode) do
    quote do
      def unquote(op)(list) when is_list(list) do
        %Q{query: [unquote(opcode), Enum.map(list, &wrap/1)]}
      end
    end
  end

  def wrap(list) when is_list(list), do: Q.make_array(list)
  def wrap(data), do: data
end
