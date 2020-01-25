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

  # # FUNCTIONS
  # # ---------------------------------------------------------------------------------------------------

  # {:@, _, [{:spec, _, [{:::, _, [{fn_name, _, [type_of_args]}, type_of_return]}]}]}
  # {:functype, _, [{fn_name, _, _}, args, type_of_return]}
  defp process({:functype, _, [{fn_name, _, _}, type_of_args, type_of_return]} = elem, env) do
    type_of_args = Enum.map(type_of_args, fn type -> TypeBuilder.build(type) end)
    fn_type = {TypeBuilder.build(type_of_return), type_of_args}

    new_module_map = Map.put(env[:modules_functions][env[:module_name]], fn_name, fn_type)
    modules_functions = Map.put(env[:modules_functions], env[:module_name], new_module_map)
    
    {elem, %{env | modules_functions: modules_functions}}
  end

  # BASE CASES
  # ---------------------------------------------------------------------------------------------------

  defp process(elem, env), do: {elem, env}
end