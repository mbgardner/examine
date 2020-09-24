defmodule ExamineExamples do
  require Examine

  # simple example
  def example_1 do
    Examine.inspect(1 + 2)
  end

  # single-line pipeline
  def example_2 do
    "cat" |> String.upcase() |> Examine.inspect()
  end

  # show_vars
  def example_3 do
    list = [1, 2, 3]

    list
    |> Enum.map(&{&1, to_string(&1 * &1)})
    |> Enum.into(%{})
    |> Examine.inspect(show_vars: true)
  end

  # show_vars and inspect_pipeline
  def example_4 do
    list = [1, 2, 3]

    list
    |> Enum.map(&{&1, to_string(&1 * &1)})
    |> Enum.into(%{})
    |> Examine.inspect(inspect_pipeline: true, show_vars: true)
  end

  # pipeline with anonymous function and sleep
  def example_5 do
    list = [1, 2, 3]

    list
    |> Enum.map(&{&1, to_string(&1 * &1)})
    |> (fn val ->
          :timer.sleep(1000)
          val
        end).()
    |> Enum.into(%{})
    |> Examine.inspect(inspect_pipeline: true, time_unit: :second)
  end

  def example_6 do
    start = 1
    increment = 1

    start
    |> Kernel.+(increment)
    |> Kernel.+(increment)
    |> Kernel.+(increment)
    |> Kernel.+(increment)
    |> Examine.inspect(
      inspect_pipeline: true,
      color: :yellow,
      bg_color: :blue,
      show_vars: true,
      time_unit: :nanosecond,
      label: "Setting A Lot of Options"
    )
  end
end
