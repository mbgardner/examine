defmodule ExamineExamples do
  require Examine

  # def show_vars() do
  #   list = [1, 2, 3]

  #   list
  #   |> Enum.map(&{&1, to_string(&1 * &1)})
  #   |> Enum.into(%{})
  #   |> Examine.inspect(show_vars: true)
  # end

  # def show_vars_and_inspect_pipeline() do
  #   list = [1, 2, 3]

  #   list
  #   |> Enum.map(&{&1, to_string(&1 * &1)})
  #   |> Enum.into(%{})
  #   |> Examine.inspect(inspect_pipeline: true, show_vars: true)
  # end

  def xxx do
    x = 7

    (x + 5)
    |> to_string
    |> String.to_integer()
    |> Examine.inspect(inspect_pipeline: true)
  end
end
