defmodule Examine do
  @moduledoc """
  Examine enhances inspect debugging by printing additional compile-time and runtime information,
  include file code and execution times.

  Global configuration:

    * `:environments` - The environments in which the `Examine.inspect/2` macro will be expanded -- in all
      other environments it will compile to a `noop`. The value is a list of atoms. Defaults to `[:dev]`.

    * `:color` - The foreground color used when printing. It must be a atom value and one of the default
      colors defined in `IO.ANSI`. Defaults to `:white`.

    * `:bg_color` - The background color used when printing. It must be a atom value and one of the default
      colors defined in `IO.ANSI`. Defaults to `:cyan`.

    * `:time_unit` - The time unit used for measuring execution time. It must be one of units defined in
      the `System.time_unit/0` type. Defaults to `:millisecond`.

    Local option value for `:color`, `:bg_color`, and `:time_unit` will override global config.

    Example configuration in a config.exs file:

      config :examine,
        environments: [:dev, :staging],
        color: :yellow,
        bg_color: :black,
        time_unit: :second
  """

  @enabled_envs Application.get_env(:examine, :environments, [:dev])
  @default_color Application.get_env(:examine, :color, :white)
  @default_bg_color Application.get_env(:examine, :bg_color, :cyan)
  @default_time_unit Application.get_env(:examine, :time_unit, :millisecond)

  @doc """
  Prints code representation, its result, and its execution time. If used with the `:inspect_pipeline` option,
  it will print the results and times next to the file code, for each step in the pipeline preceding the call.

  Examples:

    > Examine.inspect(1 + 2)
    iex:1

      1 + 2 #=> [0ms] 3


    In a file:

    ```elixir
    start = 1
    increment = 1

    start
    |> Kernel.+(increment)
    |> Kernel.+(increment)
    |> Examine.inspect(inspect_pipeline: true, show_vars: true)
    ```

    Prints:

    ```

    ./file_name.ex:10
      increment = 1
      start = 1

      start
      |> Kernel.+(increment) #=> [0ms] 2
      |> Kernel.+(increment) #=> [0ms] 3

      Total Duration: 0ms

    ```

  Options:

    * `:show_vars` - Optional. Prints the bindings for the given context below
      the filename. Defaults to `false`.

    * `:label` - Optional. Will display a text label on the top line of the block,
      above the filename.

    * `:color` - Optional. The text color, which must be one of the `<:color>/0`
      functions in `IO.ANSI`. Defaults to `:white`.

    * `:bg_color` - Optional. The background color, which must be one of the
      `<:bg_color>_background/0` functions in `IO.ANSI`. Defaults to `:cyan`.

    * `:inspect_pipeline` - Optional. Inspect the returned values for each preceding step in
      the pipeline.

    * `:measure` - Optional. Display execution time. If used in conjunction with
      `inspect_pipeline`, it will measure the execution time for each preceding step
      in the pipeline. If there are multiple execution steps, it will also display the
      total duration below the code. Defaults to `true`.

    * `:time_unit` - Optional. The time unit used for measuring execution time. The value can
      be any of the unit options in Elixir's `System.time_unit/0` type. Defaults to `:millisecond`.
  """
  defmacro inspect(expression, opts \\ []) do
    if Mix.env() in @enabled_envs do
      validate_opts(opts)
      original_code = try_get_original_code(__CALLER__, expression)
      do_inspect(expression, [{:original_code, original_code} | opts])
    else
      expression
    end
  end

  defp do_inspect(ast, opts) do
    value_representation = opts[:original_code] || generate_value_representation(ast)

    ast =
      if opts[:original_code] && opts[:inspect_pipeline] do
        inspect_pipeline(ast)
      else
        ast
      end

    time_unit = opts[:time_unit] || @default_time_unit
    time_symbol = time_unit_symbol(time_unit)

    quote location: :keep do
      start_time = System.monotonic_time()
      result = unquote(ast)
      total_duration = System.monotonic_time() - start_time

      color = unquote(opts)[:color] || unquote(@default_color)
      bg_color = unquote(opts)[:bg_color] || unquote(@default_bg_color)
      measure = Keyword.get(unquote(opts), :measure, true)

      value_representation =
        if unquote(opts[:original_code]) do
          unquote(value_representation)
          |> Enum.map(fn {s, l} ->
            case Keyword.fetch(
                   Kernel.binding(:examine_results),
                   "_examine_result_line_#{l + 1}" |> String.to_atom()
                 ) do
              {:ok, result} ->
                if measure do
                  {:ok, duration} =
                    Keyword.fetch(
                      Kernel.binding(:examine_durations),
                      "_examine_duration_line_#{l + 1}" |> String.to_atom()
                    )

                  duration =
                    Examine.get_duration_delta(
                      Kernel.binding(:examine_durations),
                      duration,
                      l + 1
                    )

                  duration = System.convert_time_unit(duration, :native, unquote(time_unit))
                  "#{s} #=> [#{inspect(duration)}#{unquote(time_symbol)}] #{inspect(result)}"
                else
                  "#{s} #=> #{inspect(result)}"
                end

              _ ->
                s
            end
          end)
          |> Enum.join("\n")
        else
          unquote(value_representation)
        end

      result_text =
        if Kernel.binding(:examine_results) |> length > 0 do
          ""
        else
          measure_text =
            if measure do
              duration = System.convert_time_unit(total_duration, :native, unquote(time_unit))
              "[#{duration}#{unquote(time_symbol)}] "
            else
              ""
            end

          " #=> #{measure_text}#{Kernel.inspect(result, Keyword.drop(unquote(opts), [:label]))}"
        end

      duration_text =
        if measure && Kernel.binding(:examine_results) |> length() > 1 do
          duration = System.convert_time_unit(total_duration, :native, unquote(time_unit))
          "\n\n  Total Duration: #{inspect(duration)}#{unquote(time_symbol)}"
        else
          ""
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
        result_text,
        duration_text,
        "\x1B[K\n",
        IO.ANSI.reset()
      ])

      result
    end
  end

  @doc false
  defmacro _examine_capture_step(ast, line \\ 0) do
    result = Macro.var("_examine_result_line_#{line}" |> String.to_atom(), :examine_results)
    duration = Macro.var("_examine_duration_line_#{line}" |> String.to_atom(), :examine_durations)

    quote do
      start = System.monotonic_time()
      var!(unquote(result), :examine_results) = unquote(ast)
      var!(unquote(duration), :examine_durations) = System.monotonic_time() - start

      unquote(result)
    end
  end

  # inject `bind_line_var/2` into a pipeline to capture the result
  # of pipeline steps for later display
  defp inspect_pipeline(ast, count \\ 0)

  defp inspect_pipeline({_, _, []} = ast, _) do
    ast
  end

  defp inspect_pipeline(nil = ast, _) do
    ast
  end

  defp inspect_pipeline([args], _) when not is_tuple(args) do
    [args]
  end

  defp inspect_pipeline({_, _, [head | _]} = ast, _) when not is_tuple(head) do
    ast
  end

  defp inspect_pipeline({a, [line: line] = b, args}, count) when count == 0 do
    {
      {:., [], [{:__aliases__, [counter: {Examine, 2}], [:Examine]}, :_examine_capture_step]},
      [],
      [{a, b, inspect_pipeline(args, count + 1)}, line]
    }
  end

  defp inspect_pipeline([{a, [line: line] = b, args}], count) when count > 0 do
    [
      {
        {:., [], [{:__aliases__, [counter: {Examine, 2}], [:Examine]}, :_examine_capture_step]},
        [],
        [{a, b, inspect_pipeline(args, count + 1)}, line]
      }
    ]
  end

  defp inspect_pipeline([{a, [line: line] = b, args} | tail], count)
       when count > 0 and not is_nil(args) do
    [
      {
        {:., [], [{:__aliases__, [counter: {Examine, 2}], [:Examine]}, :_examine_capture_step]},
        [],
        [{a, b, inspect_pipeline(args, count + 1)}, line]
      },
      tail
    ]
    |> List.flatten()
  end

  defp inspect_pipeline(ast, _count) when is_list(ast) do
    ast
  end

  @doc false
  def get_duration_delta(durations, time, line) do
    {_, prev_duration} =
      Enum.map(durations, fn {key, val} ->
        key =
          key
          |> Atom.to_string()
          |> String.trim_leading("_examine_duration_line_")
          |> String.to_integer()

        {key, val}
      end)
      |> Enum.filter(fn {key, _} -> key < line end)
      |> Enum.max_by(fn {key, _} -> key end, fn -> {nil, nil} end)

    if prev_duration do
      time - prev_duration
    else
      time
    end
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
         true <- line_max <= caller.line,
         # source code should exists
         File.exists?(caller.file),
         {:ok, code} = File.read(caller.file),
         lines <- String.split(code, "\n"),
         call_line when call_line != nil <- Enum.at(lines, caller.line - 1),
         call_line <- String.trim(call_line),
         # call line should starts with "|>"
         true <- String.starts_with?(call_line, "|>") do
      # the max line should be at least one less than where `inspect/2` was called --
      # the AST won't have line numbers for closure syntax like `end` on its own line
      line_max = max(line_max, caller.line - 1)

      # if the first line starts with a pipe then display the arg passed in on the previous line
      start_line =
        if Enum.at(lines, line_min - 1) |> String.trim() |> String.starts_with?("|>") do
          line_min - 2
        else
          line_min - 1
        end

      # anonymous functions can lead to the caller line being included
      end_line =
        if line_max == caller.line do
          line_max - 1
        else
          line_max
        end

      lines
      |> Enum.slice(start_line..(end_line - 1))
      |> adjust_indent()
      |> Enum.zip(start_line..(end_line - 1))
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

  @time_units [:second, :millisecond, :microsecond, :nanosecond]

  # raise if options aren't valid
  defp validate_opts(opts) do
    with {:color, true} <-
           {:color,
            function_exported?(IO.ANSI, :"#{Keyword.get(opts, :color, @default_color)}", 0)},
         {:bg_color, true} <-
           {:bg_color,
            function_exported?(IO.ANSI, :"#{Keyword.get(opts, :bg_color, @default_bg_color)}", 0)},
         {:time_unit, true} <-
           {:time_unit, Keyword.get(opts, :time_unit, @default_time_unit) in @time_units} do
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

      {:time_unit, _} ->
        raise "expected a time_unit in #{@time_units}, got #{Kernel.inspect(opts[:time_unit])}"
    end
  end

  defp time_unit_symbol(:nanosecond), do: "ns"
  defp time_unit_symbol(:microsecond), do: "\u00b5s"
  defp time_unit_symbol(:second), do: "s"
  # defaults to millisecond
  defp time_unit_symbol(_), do: "ms"
end
