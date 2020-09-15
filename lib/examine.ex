defmodule Examine do
  @moduledoc """
  Examine helps with debugging by presenting contextual information around a `IO.inspect/1`.
  """

  @enabled_envs Application.get_env(:examine, :environments, [:dev])
  @default_color Application.get_env(:examine, :color, :white)
  @default_bg_color Application.get_env(:examine, :bg_color, :cyan)

  @doc """
  Displays additional context around `IO.inspect/2`, with options to increase the context
  and capture pipeline results.

  Options:

    * `:show_vars` - Optional. Prints the bindings for the given context below
      the filename. Defaults to `false`.

    * `:label` - Optional. Will display a text label on the top line of the block,
      above the filename. If present, this value is stripped from the opts passed
      to `IO.inspect/2`.

    * `:color` - Optional. The text color, which must be one of the `<:color>/0`
      functions in `IO.ANSI`. Defaults to `:white`.

    * `:bg_color` - Optional. The background color, which must be one of the
      `<:bg_color>_background/0` functions in `IO.ANSI`. Defaults to `:cyan`.

    * `:inspect_pipeline` - Optional. Inspect the returned values for each preceding step of
      the pipeline.
  """
  defmacro inspect(ast, opts \\ []) do
    if Mix.env() in @enabled_envs do
      validate_opts(opts)
      original_code = try_get_original_code(__CALLER__, ast)
      do_inspect(ast, [{:original_code, original_code} | opts])
    else
      ast
    end
  end

  defp do_inspect(ast, opts) do
    value_representation = opts[:original_code] || generate_value_representation(ast)

    ast =
      if opts[:inspect_pipeline] do
        inspect_pipeline(ast)
      else
        ast
      end

    quote do
      result = unquote(ast)
      color = unquote(opts)[:color] || unquote(@default_color)
      bg_color = unquote(opts)[:bg_color] || unquote(@default_bg_color)

      value_representation =
        if unquote(opts[:original_code]) do
          unquote(value_representation)
          |> Enum.map(fn {s, l} ->
            case Keyword.fetch(
                   Kernel.binding(:examine_vars),
                   "_examine_line_#{l + 1}" |> String.to_atom()
                 ) do
              {:ok, val} ->
                "#{s} #=> #{inspect(val)}"

              _ ->
                s
            end
          end)
          |> Enum.join("\n")
        else
          unquote(value_representation)
        end

      IO.puts(:stderr, [
        apply(IO.ANSI, :"#{color}", []),
        apply(IO.ANSI, :"#{bg_color}_background", []),
        IO.ANSI.bright(),
        "\x1B[K",
        Examine.label(unquote(opts)[:label]),
        Examine.short_file_name(__ENV__.file),
        ":",
        to_string(__ENV__.line)
      ])

      if unquote(opts)[:show_vars] do
        Kernel.binding() |> Examine.print_vars()
      end

      IO.puts(:stderr, [
        "\n",
        value_representation,
        " #=> ",
        Kernel.inspect(result, Keyword.drop(unquote(opts), [:label])),
        "\x1B[K\n",
        IO.ANSI.reset()
      ])

      result
    end
  end

  @doc false
  defmacro bind_line_var(val, line \\ 0) do
    name = Macro.var("_examine_line_#{line}" |> String.to_atom(), Examine)

    quote do
      var!(unquote(name), :examine_vars) = unquote(val)
      unquote(val)
    end
  end

  # inject `bind_line_var/2` into a pipeline to capture the result
  # of pipeline steps for later display
  defp inspect_pipeline(ast, count \\ 0)

  defp inspect_pipeline({_, _, []} = ast, _) do
    ast
  end

  defp inspect_pipeline([args], _) when not is_tuple(args) do
    [args]
  end

  defp inspect_pipeline({_, _, [head | _]} = ast, _) when not is_tuple(head) do
    ast
  end

  defp inspect_pipeline({a, b, args}, count) when count == 0 do
    {a, b, inspect_pipeline(args, count + 1)}
  end

  defp inspect_pipeline([{a, [line: line] = b, args}], count) when count > 0 do
    [
      {
        {:., [], [{:__aliases__, [counter: {Examine, 2}], [:Examine]}, :bind_line_var]},
        [],
        [{a, b, inspect_pipeline(args, count + 1)}, line]
      }
    ]
  end

  defp inspect_pipeline(ast, _) when is_list(ast) do
    ast
  end

  @doc false
  def print_vars(vars) do
    vars
    |> Enum.each(fn {var_name, var_value} ->
      IO.puts(:stderr, ["  #{var_name} = ", Kernel.inspect(var_value), "\x1B[K"])
    end)
  end

  @doc false
  def short_file_name(file_name) do
    String.replace(file_name, File.cwd!(), ".")
  end

  defp generate_value_representation(ast) do
    re =
      ast
      |> Macro.to_string()
      |> Code.format_string!(line_length: 60)
      |> Enum.join()
      |> String.replace("\n", "\n  ")

    "  " <> re
  end

  @doc false
  def label(label) when is_binary(label), do: label <> "\n\n"
  def label(_), do: "\n"

  # return code from file when the code has pipeline forms
  defp try_get_original_code(caller, ast) do
    with true <- caller.file != "iex",
         # pipeline code should have at least 2 lines
         {line_min, line_max}
         when line_min != nil and line_max != nil and line_min < line_max <-
           get_code_line_range(ast),
         # pipeline code should be above the call line
         true <- line_max < caller.line,
         # source code should exists
         File.exists?(caller.file),
         {:ok, code} = File.read(caller.file),
         lines <- String.split(code, "\n"),
         call_line when call_line != nil <- Enum.at(lines, caller.line - 1),
         call_line <- String.trim(call_line),
         # call line should starts with "|>"
         true <- String.starts_with?(call_line, "|>") do
      # if the first line starts with a pipe then display the arg passed in on the previous line
      start_line =
        if Enum.at(lines, line_min - 1) |> String.trim() |> String.starts_with?("|>") do
          line_min - 2
        else
          line_min - 1
        end

      lines
      |> Enum.slice(start_line..(line_max - 1))
      |> adjust_indent()
      |> Enum.zip(start_line..(line_max - 1))
    else
      _ -> nil
    end
  end

  defp adjust_indent(lines) do
    min_indent =
      lines
      |> Enum.map(fn line ->
        len1 = byte_size(line)
        len2 = String.trim_leading(line, " ") |> byte_size()
        len1 - len2
      end)
      |> Enum.min(fn -> 0 end)

    lines
    |> Enum.map(&String.slice(&1, min_indent..-1))
    |> Enum.map(&"  #{&1}")
  end

  defp get_code_line_range(ast) do
    {_, range} =
      Macro.postwalk(ast, {nil, nil}, fn
        {_, [{:line, line} | _], _} = ast, {line_min, line_max} ->
          line_min = min(line, line_min || line)
          line_max = max(line, line_max || line)
          {ast, {line_min, line_max}}

        ast, acc ->
          {ast, acc}
      end)

    range
  end

  # raise if options aren't valid
  defp validate_opts(opts) do
    with {:color, true} <-
           {:color,
            Kernel.function_exported?(IO.ANSI, :"#{Keyword.get(opts, :color, @default_color)}", 0)},
         {:bg_color, true} <-
           {:bg_color,
            Kernel.function_exported?(
              IO.ANSI,
              :"#{Keyword.get(opts, :bg_color, @default_bg_color)}",
              0
            )} do
      :ok
    else
      {:color, _} ->
        raise "expected a valid IO.ANSI color matching a [color]/0 function, got #{
                Kernel.inspect(opts[:color])
              }"

      {:bg_color, _} ->
        raise "expected a valid IO.ANSI color matching a [color]_background/0 function, got #{
                Kernel.inspect(opts[:bg_color])
              }"
    end
  end
end
