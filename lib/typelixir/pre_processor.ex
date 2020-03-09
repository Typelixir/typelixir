defmodule Typelixir.PreProcessor do
  @moduledoc false

  alias Typelixir.{TypeBuilder}

  def process_file(path, modules_functions) do 
    ast = Code.string_to_quoted(File.read!(Path.absname(path)))
    env = %{
      module_name: :empty,
      modules_functions: modules_functions
    }
    
    {_ast, result} = Macro.prewalk(ast, env, &pre_process(&1, &2))
    result[:modules_functions]
  end

  # MODULES
  # ---------------------------------------------------------------------------------------------------

  # {:defmodule, _, MODULE}
  defp pre_process({:defmodule, _, [{:__aliases__, _, [module_name]} | [[_tail]]]} = elem, env) do
    env = %{env | module_name: module_name}
    modules_functions = Map.put(env[:modules_functions], env[:module_name], Map.new())
    {elem, %{env | modules_functions: modules_functions}}
  end

  # FUNCTIONS
  # ---------------------------------------------------------------------------------------------------

  defp pre_process({:@, _, [{:spec, _, [{:::, _, [{fn_name, _, type_of_args}, type_of_return]}]}]} = elem, env) do
    type_of_args = Enum.map(type_of_args, fn type -> TypeBuilder.build(type, %{vars: env[:vars], mod_funcs: env[:modules_functions]}) end)
    fn_type = {TypeBuilder.build(type_of_return, %{vars: env[:vars], mod_funcs: env[:modules_functions]}), type_of_args}

    new_module_map = Map.put(env[:modules_functions][env[:module_name]], fn_name, fn_type)
    modules_functions = Map.put(env[:modules_functions], env[:module_name], new_module_map)
    
    {elem, %{env | modules_functions: modules_functions}}
  end

  # BASE CASE
  # ---------------------------------------------------------------------------------------------------

  defp pre_process(elem, env), do: {elem, env}
end
