defmodule Typelixir.ModuleNamesExtractor do
  @moduledoc false

  # returns the map %{module_name => path_in_which_the_module_is}
  
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
    {_ast, result} =
      path
      |> Path.absname()
      |> File.read!()
      |> Code.string_to_quoted()
      |> Macro.prewalk(%{prefix: nil, names: []}, &extract(&1, &2))

    Enum.map(result[:names], fn module -> {module, path} end)
  end

  defp extract({:defmodule, [line: line], [{:__aliases__, meta, module_name}, [do: block]]}, env) do
    elem = {:defmodule, [line: line], [{:__aliases__, meta, module_name}, [do: {:__block__, [], []}]]}
    name = 
      module_name 
      |> Enum.map(fn name -> Atom.to_string(name) end) 
      |> Enum.join(".")
    
    new_mod_name = if env[:prefix], do: env[:prefix] <> "." <> name, else: name
    {_ast, result} = Macro.prewalk(block, %{prefix: new_mod_name, names: []}, &extract(&1, &2))
    
    {elem, %{env | names: env[:names] ++ [new_mod_name] ++ result[:names]}}
  end

  defp extract(elem, acc), do: {elem, acc}
end