defmodule ExamineTest do
  use ExUnit.Case
  doctest Examine

  test "greets the world" do
    assert Examine.hello() == :world
  end
end
