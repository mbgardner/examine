defmodule ExamineExamples do
  require Examine

  # show_vars
  def example_1 do
    list = [1, 2, 3]

    list
    |> Enum.map(&{&1, to_string(&1 * &1)})
    |> Enum.into(%{})
    |> Examine.inspect(show_vars: true)
  end

  # show_vars and inspect_pipeline
  def example_2 do
    list = [1, 2, 3]

    list
    |> Enum.map(&{&1, to_string(&1 * &1)})
    |> Enum.into(%{})
    |> Examine.inspect(inspect_pipeline: true, show_vars: true)
  end

  # pipeline with anonymous function and sleep
  def example_3 do
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

  # single-line pipeline
  def example_4 do
    "cat" |> String.upcase() |> Examine.inspect()
  end
end
