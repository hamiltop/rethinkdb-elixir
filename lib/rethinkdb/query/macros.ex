defmodule RethinkDB.Query.Macros do
  alias RethinkDB.Q
  alias RethinkDB.Query
  @moduledoc false

  defmacro operate_on_two_args(op, opcode, options \\ []) do
    opt_support = Keyword.get(options, :opts, false)

    quote do
      def unquote(op)(left, right) do
        %Q{query: [unquote(opcode), [wrap(left), wrap(right)]]}
      end

      if unquote(opt_support) do
        def unquote(op)(left, right, opts) when is_map(opts) or is_list(opts) do
          %Q{query: [unquote(opcode), [wrap(left), wrap(right)], make_opts(opts)]}
        end
      end
    end
  end

  defmacro operate_on_three_args(op, opcode, options \\ []) do
    opt_support = Keyword.get(options, :opts, false)

    quote do
      def unquote(op)(arg1, arg2, arg3) do
        %Q{query: [unquote(opcode), [wrap(arg1), wrap(arg2), wrap(arg3)]]}
      end

      if unquote(opt_support) do
        def unquote(op)(arg1, arg2, arg3, opts) when is_map(opts) or is_list(opts) do
          %Q{query: [unquote(opcode), [wrap(arg1), wrap(arg2), wrap(arg3)], make_opts(opts)]}
        end
      end
    end
  end

  defmacro operate_on_list(op, opcode, options \\ []) do
    opt_support = Keyword.get(options, :opts, false)

    quote do
      def unquote(op)(args) when is_list(args) do
        %Q{query: [unquote(opcode), Enum.map(args, &wrap/1)]}
      end

      if unquote(opt_support) do
        def unquote(op)(args, opts) when is_list(args) and (is_map(opts) or is_list(opts)) do
          %Q{query: [unquote(opcode), Enum.map(args, &wrap/1), make_opts(opts)]}
        end
      end
    end
  end

  defmacro operate_on_seq_and_list(op, opcode, options \\ []) do
    opt_support = Keyword.get(options, :opts, false)

    quote do
      def unquote(op)(seq, args) when is_list(args) and args != [] do
        %Q{query: [unquote(opcode), [wrap(seq) | Enum.map(args, &wrap/1)]]}
      end

      if unquote(opt_support) do
        def unquote(op)(seq, args, opts)
            when is_list(args) and args != [] and (is_map(opts) or is_list(opts)) do
          %Q{query: [unquote(opcode), [wrap(seq) | Enum.map(args, &wrap/1)], make_opts(opts)]}
        end
      end
    end
  end

  defmacro operate_on_single_arg(op, opcode, options \\ []) do
    opt_support = Keyword.get(options, :opts, false)

    quote do
      def unquote(op)(arg) do
        %Q{query: [unquote(opcode), [wrap(arg)]]}
      end

      if unquote(opt_support) do
        def unquote(op)(arg, opts) when is_map(opts) or is_list(opts) do
          %Q{query: [unquote(opcode), [wrap(arg)], make_opts(opts)]}
        end
      end
    end
  end

  defmacro operate_on_optional_second_arg(op, opcode) do
    quote do
      def unquote(op)(arg) do
        %Q{query: [unquote(opcode), [wrap(arg)]]}
      end

      def unquote(op)(left, right = %Q{}) do
        %Q{query: [unquote(opcode), [wrap(left), wrap(right)]]}
      end

      def unquote(op)(arg, opts) when is_map(opts) do
        %Q{query: [unquote(opcode), [wrap(arg)], opts]}
      end

      def unquote(op)(left, right, opts) when is_map(opts) do
        %Q{query: [unquote(opcode), [wrap(left), wrap(right)], opts]}
      end

      def unquote(op)(left, right) do
        %Q{query: [unquote(opcode), [wrap(left), wrap(right)]]}
      end
    end
  end

  defmacro operate_on_zero_args(op, opcode, options \\ []) do
    opt_support = Keyword.get(options, :opts, false)

    quote do
      def unquote(op)(), do: %Q{query: [unquote(opcode)]}

      if unquote(opt_support) do
        def unquote(op)(opts) when is_map(opts) or is_list(opts) do
          %Q{query: [unquote(opcode), make_opts(opts)]}
        end
      end
    end
  end

  def wrap(list) when is_list(list), do: Query.make_array(Enum.map(list, &wrap/1))
  def wrap(q = %Q{}), do: q

  def wrap(t = %RethinkDB.Pseudotypes.Time{}) do
    m = Map.from_struct(t) |> Map.put_new("$reql_type$", "TIME")
    wrap(m)
  end

  def wrap(t = %DateTime{utc_offset: utc_offset, std_offset: std_offset}) do
    offset = utc_offset + std_offset
    offset_negative = offset < 0
    offset_hour = div(abs(offset), 3600)
    offset_minute = rem(abs(offset), 3600)

    time_zone =
      if offset_negative do
        "-"
      else
        "+"
      end <>
        String.pad_leading(Integer.to_string(offset_hour), 2, "0") <>
        ":" <> String.pad_leading(Integer.to_string(offset_minute), 2, "0")

    wrap(%{
      "$reql_type$" => "TIME",
      "epoch_time" => DateTime.to_unix(t, :milliseconds) / 1000,
      "timezone" => time_zone
    })
  end

  def wrap(map) when is_map(map) do
    Enum.map(map, fn {k, v} ->
      {k, wrap(v)}
    end)
    |> Enum.into(%{})
  end

  def wrap(f) when is_function(f), do: Query.func(f)
  def wrap(t) when is_tuple(t), do: wrap(Tuple.to_list(t))
  def wrap(data), do: data

  def make_opts(opts) when is_map(opts), do: wrap(opts)
  def make_opts(opts) when is_list(opts), do: Enum.into(opts, %{})
end
