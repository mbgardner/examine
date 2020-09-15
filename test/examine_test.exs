defmodule ExamineTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  require Examine

  def capture_inspect(fun) do
    capture_io(:stderr, fun)
    |> String.replace("\e[37m\e[46m\e[1m\e[K\n", "")
    |> String.replace("\e[K\n\e[0m\n", "")
    |> String.replace("\e[K", "")
    |> String.split("\n")
    |> Enum.filter(&(String.length(&1) > 0))
  end

  test "inspect of a simple var" do
    fun = fn ->
      x = 7
      Examine.inspect(x)
    end

    assert capture_inspect(fun) == [
             "./test/examine_test.exs:18",
             "  x #=> 7"
           ]
  end

  test "inspect of a simple expression" do
    fun = fn ->
      x = 7
      y = 5
      Examine.inspect(x + y)
    end

    assert capture_inspect(fun) == [
             "./test/examine_test.exs:31",
             "  x + y #=> 12"
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
             "./test/examine_test.exs:47",
             "  (x + 5)",
             "  |> to_string",
             "  |> String.to_integer() #=> 12"
           ]
  end

  test "inspect of a pipeline with more complex result" do
    fun = fn ->
      list = [1, 2, 3]

      list
      |> Enum.map(&{&1, to_string(&1 * &1)})
      |> Enum.into(%{})
      |> Examine.inspect()
    end

    assert capture_inspect(fun) == [
             "./test/examine_test.exs:65",
             "  list",
             "  |> Enum.map(&{&1, to_string(&1 * &1)})",
             "  |> Enum.into(%{}) #=> %{1 => \"1\", 2 => \"4\", 3 => \"9\"}"
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
             "./test/examine_test.exs:82",
             "  (x + 5)",
             "  |> to_string #=> \"12\""
           ]
  end

  test "inspect with show_vars option" do
    fun = fn ->
      x = 7
      y = 5
      Examine.inspect(x + y, show_vars: true)
    end

    assert capture_inspect(fun) == [
             "./test/examine_test.exs:97",
             "  x = 7",
             "  y = 5",
             "  x + y #=> 12"
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
             "./test/examine_test.exs:115",
             "  list = [1, 2, 3]",
             "  list",
             "  |> Enum.map(&{&1, to_string(&1 * &1)})",
             "  |> Enum.into(%{}) #=> %{1 => \"1\", 2 => \"4\", 3 => \"9\"}"
           ]
  end

  test "inspect with passing expression directly w/o pipe operator" do
    fun = fn ->
      {x, y} = {5, 7}
      Examine.inspect(x |> max(y), show_vars: true)
    end

    assert capture_inspect(fun) == [
             "./test/examine_test.exs:130",
             "  x = 5",
             "  y = 7",
             "  x |> max(y) #=> 7"
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
             "./test/examine_test.exs:146",
             "  5",
             "  |> to_string #=> \"5\"",
             "  |> String.to_integer() #=> 5"
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
             "./test/examine_test.exs:164",
             "  (x + 5) #=> 12",
             "  |> to_string #=> \"12\"",
             "  |> String.to_integer() #=> 12"
           ]
  end
end
