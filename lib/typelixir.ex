defmodule Typelixir do
  @moduledoc false

  def check(file) do
    IO.inspect Code.string_to_quoted([], file: file)
  end
end
