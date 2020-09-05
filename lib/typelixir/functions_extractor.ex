defmodule Typelixir.FunctionsExtractor do
  @moduledoc false

  alias Typelixir.{PatternBuilder, TypeComparator, Utils}

  # extends the given functions env map with the module name and the functions it defines

  def extract_functions_file(path, env) do 
    ast = Code.string_to_quoted(File.read!(Path.absname(path)))    
    {_ast, result} = Macro.prewalk(ast, env, &extract(&1, &2))
    
    Utils.prepare_result_data(result)
  end

  # MODULES
  # ---------------------------------------------------------------------------------------------------

  # {:defmodule, _, MODULE}
  defp extract({:defmodule, [line: line], [{:__aliases__, meta, module_name}, [do: block]]}, env) do
    elem = {:defmodule, [line: line], [{:__aliases__, meta, module_name}, [do: {:__block__, [], []}]]}
    name = 
      module_name 
      |> Enum.map(fn name -> Atom.to_string(name) end) 
      |> Enum.join(".")
    
    new_mod_name = if env[:prefix], do: env[:prefix] <> "." <> name, else: name
    new_functions = Map.put(env[:functions], new_mod_name, Map.new())
    {_ast, result} = Macro.prewalk(block, %{env | functions: new_functions, prefix: new_mod_name}, &extract(&1, &2))

    {elem, %{env | state: result[:state], error_data: result[:error_data], functions: Map.merge(env[:functions], result[:functions])}}
  end

  # FUNCTIONS
  # ---------------------------------------------------------------------------------------------------

  defp extract({:@, [line: line], [{:spec, _, [{:::, _, [{fn_name, _, type_of_args}, type_of_return]}]}]} = elem, env) do
    type_of_args = Enum.map(type_of_args || [], fn type -> PatternBuilder.type(type, %{}) end)

    case TypeComparator.has_type?(type_of_args, :error) do
      true -> {elem, %{env | state: :error, error_data: Map.put(env[:error_data], line, "Malformed type spec on #{fn_name}/#{length(type_of_args)} parameters")}}
      _ ->
        return_type = PatternBuilder.type(type_of_return, %{})

        case TypeComparator.has_type?(return_type, :error) do
          true -> {elem, %{env | state: :error, error_data: Map.put(env[:error_data], line, "Malformed type spec on #{fn_name}/#{length(type_of_args)} return")}}
          _ -> 
            fn_type = {return_type, type_of_args}
            fn_key = {fn_name, length(type_of_args)}

            case (env[:functions][env[:prefix]][fn_key]) do
              nil ->
                new_module_map = Map.put(env[:functions][env[:prefix]], {fn_name, length(type_of_args)}, fn_type)
                new_functions = Map.put(env[:functions], env[:prefix], new_module_map)
              
                {elem, %{env | functions: new_functions}}
              _ -> 
                {elem, %{env | state: :error, error_data: Map.put(env[:error_data], line, "#{fn_name}/#{length(type_of_args)} already has a defined type")}}
            end
        end
    end
  end

  # BASE CASE
  # ---------------------------------------------------------------------------------------------------

  defp extract(elem, env), do: {elem, env}
end
