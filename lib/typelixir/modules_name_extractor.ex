defmodule Typelixir.ModuleNamesExtractor do
  @moduledoc false
  
  def extract_modules_names(all_paths) do
    modules_paths = 
      all_paths
      |> Enum.map(fn path -> extract_module_names_file(path) end)
      |> List.flatten()
      |> Enum.into(%{})

    # while developing to see the info in the console
    IO.puts(["Modules map => ", inspect modules_paths])
    modules_paths
  end

  defp extract_module_names_file(path) do
    path
    |> Path.absname()
    |> File.read!()
    |> Code.string_to_quoted()
    |> Macro.prewalk([], &extract(&1, &2))
    |> elem(1)
    |> Enum.map(fn module -> {module, path} end)
  end

  defp extract({:defmodule, _, [{:__aliases__, _, [module_name]}, _]} = elem, names), do: {elem, names ++ [module_name]}

  defp extract(elem, acc), do: {elem, acc}
end