defmodule ExamineExamples do
  require Examine

  def show_vars() do
    list = [1, 2, 3]

    list
    |> Enum.map(&{&1, to_string(&1 * &1)})
    |> Enum.into(%{})
    |> Examine.inspect(show_vars: true)
  end

  def inspect_pipeline do
    list = [1, 2, 3]

    list
    |> Enum.map(&{&1, to_string(&1 * &1)})
    |> Enum.into(%{})
    |> Examine.inspect(inspect_pipeline: true)
  end

  def pipeline_with_anonymous_func_and_sleep do
    list = [1, 2, 3]

    list
    |> Enum.map(&{&1, to_string(&1 * &1)})
    |> (fn val ->
          :timer.sleep(1000)
          val
        end).()
    |> (fn val ->
          :timer.sleep(1000)
          val
        end).()
    |> Enum.into(%{})
    |> Examine.inspect(inspect_pipeline: true)
  end

  def inline do
    "cat" |> String.upcase() |> Examine.inspect()
  end
end
