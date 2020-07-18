defmodule Typelixir.PreProcessor do
  @moduledoc false

  alias Typelixir.{PatternBuilder}

  # extends the given map with the module name as key and the typed functions it defines as value

  def process_file(path, env) do 
    ast = Code.string_to_quoted(File.read!(Path.absname(path)))    
    {_ast, result} = Macro.prewalk(ast, env, &pre_process(&1, &2))
    result
  end

  # MODULES
  # ---------------------------------------------------------------------------------------------------

  # {:defmodule, _, MODULE}
  defp pre_process({:defmodule, [line: line], [{:__aliases__, meta, module_name}, [do: block]]}, env) do
    elem = {:defmodule, [line: line], [{:__aliases__, meta, module_name}, [do: {:__block__, [], []}]]}
    name = 
      module_name 
      |> Enum.map(fn name -> Atom.to_string(name) end) 
      |> Enum.join(".")
    
    new_mod_name = if env[:prefix], do: env[:prefix] <> "." <> name, else: name
    new_functions = Map.put(env[:modules_functions], new_mod_name, Map.new())
    {_ast, result} = Macro.prewalk(block, %{env | modules_functions: new_functions, prefix: new_mod_name}, &pre_process(&1, &2))

    {elem, %{env | state: result[:state], error_data: result[:error_data], modules_functions: Map.merge(env[:modules_functions], result[:modules_functions])}}
  end

  # FUNCTIONS
  # ---------------------------------------------------------------------------------------------------

  defp pre_process({:@, [line: line], [{:spec, _, [{:::, _, [{fn_name, _, type_of_args}, type_of_return]}]}]} = elem, env) do
    type_of_args = Enum.map(type_of_args, fn type -> PatternBuilder.type(type, %{}) end)
    fn_type = {PatternBuilder.type(type_of_return, %{}), type_of_args}
    fn_key = {fn_name, length(type_of_args)}

    if (env[:modules_functions][env[:prefix]][fn_key]) do
      {elem, %{env | state: :error, error_data: Map.put(env[:error_data], line, "#{fn_name}/#{length(type_of_args)} already has a defined type")}}
    else
      new_module_map = Map.put(env[:modules_functions][env[:prefix]], {fn_name, length(type_of_args)}, fn_type)
      new_functions = Map.put(env[:modules_functions], env[:prefix], new_module_map)
    
      {elem, %{env | modules_functions: new_functions}}
    end
  end

  # BASE CASE
  # ---------------------------------------------------------------------------------------------------

  defp pre_process(elem, env), do: {elem, env}
end
