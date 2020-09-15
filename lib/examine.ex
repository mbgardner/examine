defmodule Examine do
  @moduledoc """
  Examine helps with debugging by presenting contextual information around a `IO.inspect/1`.
  """

  @doc """
  Prints the first argument, calling `IO.inspect/2`, while also providing default and optional
  context. By default, it will display both the line of code and the filename and file line. If
  called in a pipeline, it will display all of the preceding lines to the start of the pipeline.

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

  ## Examples
      > x = 7
      > x |> Dbg.inspect()

      ./dbg.ex:16
      x # => 7
      > {x, y} = {5, 7}
      > Dbg.inspect(x+y)
      ./dbg.ex:22
      x + y # => 12
  See more examples in tests.
  """

  defp aaa(ast, count \\ 0)

  defp aaa({a, b, []}, _) do
    IO.puts "B"
    {a, b, []}
  end

  defp aaa([args], _) when not is_tuple(args) do
    IO.puts "D"
    [args]
  end

  defp aaa({_, _, [head | _]} = ast, _) when not is_tuple(head) do
    IO.puts "A"
    ast
  end

  defp aaa({a, b, args}, count) when count == 0 do
    IO.puts "C"
    {a, b, aaa(args, count + 1)}
  end

  defp aaa([{a, [line: line] = b, args}], count) when count > 0 do
    IO.puts "in here"
    [{
      {:., [], [{:__aliases__, [counter: {Examine, 2}], [:Examine]}, :bind_line_var]},
      [],
      [{a, b, aaa(args, count + 1)}, line]
    }]
  end


  defmacro inspect(ast, opts \\ []) do
    original_code = try_get_original_code(__CALLER__, ast)
    inspect(Mix.env(), ast, [{:original_code, original_code} | opts])
  end

  @enabled_envs Application.get_env(:examine, :environments, [:dev, :test])
  @default_color Application.get_env(:examine, :color, :white)
  @default_bg_color Application.get_env(:examine, :bg_color, :cyan)

  defp inspect(env, ast, _opts) when env not in @enabled_envs, do: ast

  defp inspect(_env, ast, opts) do
    value_representation = opts[:original_code] || generate_value_representation(ast)
    ast = aaa(ast) |> IO.inspect(label: "aaa result")

    quote do
      require Examine

      result = unquote(ast)
      color = unquote(opts)[:color] || unquote(@default_color)
      bg_color = unquote(opts)[:bg_color] || unquote(@default_bg_color)


      value_representation =
      if unquote(opts[:original_code]) do
          unquote(value_representation)
        |> Enum.map(fn {s, l} ->
          case Keyword.fetch(Kernel.binding(:examine_vars), "_examine_line_#{l + 1}" |> String.to_atom()) do
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
        IO.ANSI.reset(),
        #var!(examine__262, :blah)
      ])

      result
    end
  end

  defmacro bind_line_var(val, line \\ 0) do
    name = Macro.var("_examine_line_#{line}" |> String.to_atom, Examine)

    quote do
      var!(unquote(name), :examine_vars) = unquote(val)
      unquote(val)
    end
  end

  def print_vars(vars) do
    vars
    |> Enum.each(fn {var_name, var_value} ->
      IO.puts(:stderr, ["  #{var_name} = ", Kernel.inspect(var_value), "\x1B[K"])
    end)
  end

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
          start_line = if Enum.at(lines, line_min - 1) |> String.trim |> String.starts_with?("|>") do
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
end

defmodule Test do
  require Examine

  def foo do
    "foo"
    |> String.capitalize()
    |> String.upcase()
    |> String.downcase()
    |> Examine.inspect(inspect_pipeline: true, show_vars: true)
  end

  def foo2 do
    1 + 2 |> Examine.inspect()
  end

  def foo3 do
    "foo3" |> String.upcase() |> String.downcase() |> Examine.inspect()
  end

  def foo4 do
    "foo4"
    |> String.upcase()
    |> Examine.inspect()
  end
end
