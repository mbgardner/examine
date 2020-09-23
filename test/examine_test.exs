defmodule ExamineTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  require Examine
  alias ExamineExamples, as: Examples

  test "inspect of a simple var" do
    fun = fn ->
      x = 7
      Examine.inspect(x)
    end

    assert capture_inspect(fun) == [
             "./test/examine_test.exs:#",
             "  x #=> [#ms] 7"
           ]
  end

  test "inspect of a simple expression" do
    fun = fn ->
      x = 7
      y = 5
      Examine.inspect(x + y)
    end

    assert capture_inspect(fun) == [
             "./test/examine_test.exs:#",
             "  x + y #=> [#ms] 12"
           ]
  end

  test "inspect of a pipeline" do
    fun = fn ->
      x = 7

      (x + 5)
      |> to_string
      |> String.to_integer()
      |> Examine.inspect()
    end

    assert capture_inspect(fun) == [
             "./test/examine_test.exs:#",
             "  (x + 5)",
             "  |> to_string",
             "  |> String.to_integer() #=> [#ms] 12"
           ]
  end

  test "inspect in the middle of pipeline" do
    fun = fn ->
      x = 7

      (x + 5)
      |> to_string
      |> Examine.inspect()
      |> String.to_integer()
    end

    assert capture_inspect(fun) == [
             "./test/examine_test.exs:#",
             "  (x + 5)",
             "  |> to_string #=> [#ms] \"12\""
           ]
  end

  test "inspect with show_vars option" do
    fun = fn ->
      x = 7
      y = 5
      Examine.inspect(x + y, show_vars: true)
    end

    assert capture_inspect(fun) == [
             "./test/examine_test.exs:#",
             "  x = 7",
             "  y = 5",
             "  x + y #=> [#ms] 12"
           ]
  end

  test "inspect of an expression with more complex result and show_vars on" do
    fun = fn ->
      list = [1, 2, 3]

      list
      |> Enum.map(&{&1, to_string(&1 * &1)})
      |> Enum.into(%{})
      |> Examine.inspect(show_vars: true)
    end

    assert capture_inspect(fun) == [
             "./test/examine_test.exs:#",
             "  list = [1, 2, 3]",
             "  list",
             "  |> Enum.map(&{&1, to_string(&1 * &1)})",
             "  |> Enum.into(%{}) #=> [#ms] %{1 => \"1\", 2 => \"4\", 3 => \"9\"}"
           ]
  end

  test "inspect with passing expression directly w/o pipe operator" do
    fun = fn ->
      {x, y} = {5, 7}
      Examine.inspect(x |> max(y), show_vars: true)
    end

    assert capture_inspect(fun) == [
             "./test/examine_test.exs:#",
             "  x = 5",
             "  y = 7",
             "  x |> max(y) #=> [#ms] 7"
           ]
  end

  test "inspect with inspect_pipeline on and initial arg above" do
    fun = fn ->
      5
      |> to_string
      |> String.to_integer()
      |> Examine.inspect(inspect_pipeline: true)
    end

    assert capture_inspect(fun) == [
             "./test/examine_test.exs:#",
             "  5",
             "  |> to_string #=> [#ms] \"5\"",
             "  |> String.to_integer() #=> [#ms] 5",
             "  Total Duration: #ms"
           ]
  end

  test "inspect of an expression with more complex result and inspect_pipeline on" do
    fun = fn ->
      list = [1, 2, 3]

      list
      |> Enum.map(&{&1, to_string(&1 * &1)})
      |> Enum.into(%{})
      |> Examine.inspect(inspect_pipeline: true)
    end

    assert capture_inspect(fun) == [
             "./test/examine_test.exs:#",
             "  list",
             "  |> Enum.map(&{&1, to_string(&1 * &1)}) #=> [#ms] [{1, \"1\"}, {2, \"4\"}, {3, \"9\"}]",
             "  |> Enum.into(%{}) #=> [#ms] %{1 => \"1\", 2 => \"4\", 3 => \"9\"}",
             "  Total Duration: #ms"
           ]
  end

  test "inspect with inspect_pipeline on and initial arg above as expression" do
    fun = fn ->
      x = 7

      (x + 5)
      |> to_string
      |> String.to_integer()
      |> Examine.inspect(inspect_pipeline: true)
    end

    assert capture_inspect(fun) == [
             "./test/examine_test.exs:#",
             "  (x + 5) #=> [#ms] 12",
             "  |> to_string #=> [#ms] \"12\"",
             "  |> String.to_integer() #=> [#ms] 12",
             "  Total Duration: #ms"
           ]
  end

  test "correctly displays example_1" do
    fun = fn -> Examples.example_1() end

    assert capture_inspect(fun) == [
             "./examples/examples.exs:6",
             "  1 + 2 #=> [#ms] 3"
           ]
  end

  test "correctly displays example_2" do
    fun = fn -> Examples.example_2() end

    assert capture_inspect(fun) == [
             "./examples/examples.exs:11",
             "  String.upcase(\"cat\") #=> [#ms] \"CAT\""
           ]
  end

  test "correctly displays example_3" do
    fun = fn -> Examples.example_3() end

    assert capture_inspect(fun) == [
             "./examples/examples.exs:21",
             "  list = [1, 2, 3]",
             "  list",
             "  |> Enum.map(&{&1, to_string(&1 * &1)})",
             "  |> Enum.into(%{}) #=> [#ms] %{1 => \"1\", 2 => \"4\", 3 => \"9\"}"
           ]
  end

  test "correctly displays example_4" do
    fun = fn -> Examples.example_4() end

    assert capture_inspect(fun) == [
             "./examples/examples.exs:31",
             "  list = [1, 2, 3]",
             "  list",
             "  |> Enum.map(&{&1, to_string(&1 * &1)}) #=> [#ms] [{1, \"1\"}, {2, \"4\"}, {3, \"9\"}]",
             "  |> Enum.into(%{}) #=> [#ms] %{1 => \"1\", 2 => \"4\", 3 => \"9\"}",
             "  Total Duration: #ms"
           ]
  end

  test "correctly displays example_5 with time values" do
    fun = fn -> Examples.example_5() end

    assert capture_inspect(fun, keep_time: true, keep_total_time: true) == [
             "./examples/examples.exs:45",
             "  list",
             "  |> Enum.map(&{&1, to_string(&1 * &1)}) #=> [0s] [{1, \"1\"}, {2, \"4\"}, {3, \"9\"}]",
             "  |> (fn val ->",
             "        :timer.sleep(1000)",
             "        val",
             "      end).() #=> [1s] [{1, \"1\"}, {2, \"4\"}, {3, \"9\"}]",
             "  |> Enum.into(%{}) #=> [0s] %{1 => \"1\", 2 => \"4\", 3 => \"9\"}",
             "  Total Duration: 1s"
           ]
  end

  defp capture_inspect(fun, opts \\ []) do
    capture_io(:stderr, fun)
    |> String.replace("\e[37m\e[46m\e[1m\e[K\n", "")
    |> String.replace("\e[K\n\e[0m\n", "")
    |> String.replace("\e[K", "")
    |> keep_line_number(opts[:keep_line_number])
    |> keep_time(opts[:keep_time])
    |> keep_total_time(opts[:keep_total_time])
    |> String.split("\n")
    |> Enum.filter(&(String.length(&1) > 0))
  end

  # keep the caller line number
  defp keep_line_number(str, true), do: str

  defp keep_line_number(str, _),
    do: String.replace(str, ~r/(examine_test.exs:)(\d+)/, "\\1#")

  # keep the execution time output
  defp keep_time(str, true), do: str
  defp keep_time(str, _), do: String.replace(str, ~r/(\[\d+ms\])/, "[#ms]")

  defp keep_total_time(str, true), do: str
  defp keep_total_time(str, _), do: String.replace(str, ~r/(Total Duration: )(\d+ms)/, "\\1#ms")
end
