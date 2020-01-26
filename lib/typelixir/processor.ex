defmodule Processor do
  @moduledoc false

  # FIRST
  # ---------------------------------------------------------------------------------------------------

  def process_file(path, env) do 
    ast = Code.string_to_quoted(File.read!(Path.absname(path)))
    
    # while developing to see the info in the console
    IO.puts "#{path} ast:"
    IO.inspect ast
    
    {_ast, result} = Macro.prewalk(ast, env, &process(&1, &2))
    result
  end

  # MODULES
  # ---------------------------------------------------------------------------------------------------

  # {:defmodule, _, MODULE}
  defp process({:defmodule, _, [{:__aliases__, _, [module_name]} | [[tail]]]} = elem, env) do
    env = %{env | module_name: module_name}
    modules_functions = Map.put(env[:modules_functions], env[:module_name], Map.new())
    {elem, %{env | modules_functions: modules_functions}}
  end

  # MODULES INTERACTION
  # ---------------------------------------------------------------------------------------------------

  # {{:., _, [{:__aliases__, _, [module_name]}, fn_name]}, _, args}
  defp process({{:., [line: line], [{:__aliases__, _, [mod_name]}, fn_name]}, _, args} = elem, env) do
    if (env[:modules_functions][mod_name][fn_name]) do
      type_of_args_caller = Enum.map(args, fn type -> TypeBuilder.build(type, env[:vars]) end)
      type_of_args_callee = elem(env[:modules_functions][mod_name][fn_name], 1)
      
      if (TypeComparator.less_or_equal?(type_of_args_caller, type_of_args_callee)), do: {elem, env},
        else: {elem, %{env | state: :error, data: {line, "Type error on function call #{mod_name}.#{fn_name}"}}}
    else 
      {elem, env}
    end
  end

  # USE, IMPORT, ALIAS, REQUIRE
  # ---------------------------------------------------------------------------------------------------

  # {:import, _, [{:__aliases__, _, [module_name]}]}
  defp process({:import, _, [{:__aliases__, _, module_name_ext}]} = elem, env) do
    [head | _] = module_name_ext
    if !env[:modules_functions][head] do
      {elem, %{env | state: :needs_compile, data: head}}
    else
      {elem, env}
    end
  end

  # FUNCTIONS
  # ---------------------------------------------------------------------------------------------------

  # {:@, _, [{:spec, _, [{:::, _, [{fn_name, _, [type_of_args]}, type_of_return]}]}]}
  # {:functype, _, [{fn_name, _, _}, args, type_of_return]}
  defp process({:functype, _, [{fn_name, _, _}, type_of_args, type_of_return]} = elem, env) do
    type_of_args = Enum.map(type_of_args, fn type -> TypeBuilder.build(type, env[:vars]) end)
    fn_type = {TypeBuilder.build(type_of_return, env[:vars]), type_of_args}

    new_module_map = Map.put(env[:modules_functions][env[:module_name]], fn_name, fn_type)
    modules_functions = Map.put(env[:modules_functions], env[:module_name], new_module_map)
    
    {elem, %{env | modules_functions: modules_functions}}
  end

  # VARIABLES
  # ---------------------------------------------------------------------------------------------------
  
  defp process({type, [_], [{variable, _, _}]} = elem, env) when (type in [:string, :boolean, :integer, :float, :atom]) do
    vars = Map.put(env[:vars], variable, type)
    {elem, %{env | vars: vars}}
  end

  defp process({:list, [_], [{variable, _, _}, type]} = elem, env) do
    vars = Map.put(env[:vars], variable, {:list, TypeBuilder.build(type, env[:vars])})
    {elem, %{env | vars: vars}}
  end

  defp process({:tuple, [_], [{variable, _, _}, types_list]} = elem, env) do
    tuple_type = Enum.map(types_list, fn type -> TypeBuilder.build(type, env[:vars]) end)
    vars = Map.put(env[:vars], variable, {:tuple, tuple_type})
    {elem, %{env | vars: vars}}
  end

  defp process({:map, [_], [{variable, _, _}, key_type, value_type]} = elem, env) do
    vars = Map.put(env[:vars], variable, {:map, {TypeBuilder.build(key_type, env[:vars]), TypeBuilder.build(value_type, env[:vars])}})
    {elem, %{env | vars: vars}}
  end

  # BASE CASES
  # ---------------------------------------------------------------------------------------------------

  defp process(elem, env), do: {elem, env}
end