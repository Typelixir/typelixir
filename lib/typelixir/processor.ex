defmodule Typelixir.Processor do
  @moduledoc false

  alias Typelixir.{TypeBuilder, TypeComparator}

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

  # HANDLE ERROR / NEEDS COMPILE
  # ---------------------------------------------------------------------------------------------------

  defp process(elem, %{:state => :error, :data => _, :module_name => _, :vars => _, :modules_functions => _} = env), do: {elem, env}

  defp process(elem, %{:state => :needs_compile, :data => _, :module_name => _, :vars => _, :modules_functions => _} = env), do: {elem, env}

  # MODULES
  # ---------------------------------------------------------------------------------------------------

  # {:defmodule, _, MODULE}
  defp process({:defmodule, _, [{:__aliases__, _, [module_name]} | [[_tail]]]} = elem, env) do
    env = %{env | module_name: module_name}
    modules_functions = Map.put(env[:modules_functions], env[:module_name], Map.new())
    {elem, %{env | modules_functions: modules_functions}}
  end

  # MODULES INTERACTION
  # ---------------------------------------------------------------------------------------------------

  # {{:., _, [{:__aliases__, _, [module_name]}, fn_name]}, _, args}
  defp process({{:., [line: line], [{:__aliases__, _, [mod_name]}, fn_name]}, _, args} = elem, env) do
    if (env[:modules_functions][mod_name][fn_name]) do
      type_of_args_caller = Enum.map(args, fn type -> TypeBuilder.build(type, %{vars: env[:vars], mod_funcs: env[:modules_functions]}) end)
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
  # {:typedfunc, _, [{fn_name, _, _}, args, type_of_return]}
  defp process({:typedfunc, _, [{fn_name, _, _}, type_of_args, type_of_return]} = elem, env) do
    type_of_args = Enum.map(type_of_args, fn type -> TypeBuilder.build(type, %{vars: env[:vars], mod_funcs: env[:modules_functions]}) end)
    fn_type = {TypeBuilder.build(type_of_return, %{vars: env[:vars], mod_funcs: env[:modules_functions]}), type_of_args}

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
    vars = Map.put(env[:vars], variable, {:list, TypeBuilder.build(type, %{vars: env[:vars], mod_funcs: env[:modules_functions]})})
    {elem, %{env | vars: vars}}
  end

  defp process({:tuple, [_], [{variable, _, _}, types_list]} = elem, env) do
    tuple_type = Enum.map(types_list, fn type -> TypeBuilder.build(type, %{vars: env[:vars], mod_funcs: env[:modules_functions]}) end)
    vars = Map.put(env[:vars], variable, {:tuple, tuple_type})
    {elem, %{env | vars: vars}}
  end

  defp process({:map, [_], [{variable, _, _}, key_type, value_type]} = elem, env) do
    vars = Map.put(env[:vars], variable, {:map, {TypeBuilder.build(key_type, %{vars: env[:vars], mod_funcs: env[:modules_functions]}), TypeBuilder.build(value_type, %{vars: env[:vars], mod_funcs: env[:modules_functions]})}})
    {elem, %{env | vars: vars}}
  end

  # BINDING
  # ---------------------------------------------------------------------------------------------------

  defp process({:=, [line: line], [operand1, operand2]} = elem, env) do
    type_operand1 = TypeBuilder.build(operand1, %{vars: env[:vars], mod_funcs: env[:modules_functions]})
    type_operand2 = TypeBuilder.build(operand2, %{vars: env[:vars], mod_funcs: env[:modules_functions]})

    case TypeComparator.less_or_equal?(type_operand2, type_operand1) do
      true -> 
        case TypeComparator.has_type?(type_operand2, nil) do
          true -> {elem, %{env | data: env[:data] ++ [{line, "Right side of = doesn't have a defined type"}]}}
          _ -> {elem, env}
        end
      _ -> 
        case TypeComparator.has_type?(type_operand1, nil) do
          true -> {elem, %{env | data: env[:data] ++ [{line, "Left side of = doesn't have a defined type"}]}}
          _ -> 
            case TypeComparator.int_to_float?(type_operand1, type_operand2) do
              true -> 
                vars = TypeBuilder.from_int_to_float(operand1, operand2, %{vars: env[:vars], mod_funcs: env[:modules_functions]})
                {elem, %{env | vars: vars, data: env[:data] ++ [{line, "Some variables on left side of = will change the type from integer to float"}]}}
              _ -> {elem, %{env | state: :error, data: {line, "Type error on = operator"}}}
            end
        end
    end
  end

  # BASE CASE
  # ---------------------------------------------------------------------------------------------------

  defp process(elem, env), do: {elem, env}
end