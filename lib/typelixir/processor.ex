defmodule Processor do
  @moduledoc false

  # FIRST
  # ---------------------------------------------------------------------------------------------------

  def process_file(path, env) do 
    ast = Code.string_to_quoted(File.read!(Path.absname(path)))
    {_ast, result} = Macro.prewalk(ast, env, &process(&1, &2))
    result
  end

  # BASE CASE
  # ---------------------------------------------------------------------------------------------------

  defp process(elem, acc), do: {elem, acc}
end