defmodule TypelixirTest do
  use ExUnit.Case
  doctest Typelixir

  test "greets the world" do
    assert Typelixir.hello() == :world
  end
end
