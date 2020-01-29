defmodule Typelixir.ModuleNamesExtractor do
  @moduledoc false

  def extract_modules_names(all_paths) do
    modules_paths = for path <- all_paths,
      into: [],
      do:
        for module <- extract_module_names_file(path),
        into: [],
        do: {module, path}
    modules_paths = Enum.into(Enum.concat(modules_paths), %{})

    # while developing to see the info in the console
    IO.puts(["Modules map => ", inspect modules_paths])

    modules_paths
  end

  defp extract_module_names_file(path) do
    ast = Code.string_to_quoted(File.read!(Path.absname(path)))
    {_ast, result} = Macro.prewalk(ast, [], &extract(&1, &2))
    result
  end

  defp extract({:defmodule, _, [{:__aliases__, _, [module_name]}, _]} = elem, names), do: {elem, names ++ [module_name]}

  defp extract(elem, acc), do: {elem, acc}
  end