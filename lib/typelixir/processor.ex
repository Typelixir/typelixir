defmodule Typelixir.Processor do
  @moduledoc false

  alias Typelixir.{TypeBuilder, TypeComparator, PreProcessor}

  # FIRST
  # ---------------------------------------------------------------------------------------------------

  def process_file(path, env) do 
    modules_functions = PreProcessor.process_file(path, env[:modules_functions])
    ast = Code.string_to_quoted(File.read!(Path.absname(path)))
    
    # while developing to see the info in the console
    IO.puts "#{path} ast:"
    IO.inspect ast
    
    {_ast, result} = Macro.prewalk(ast, %{env | modules_functions: modules_functions}, &process(&1, &2))
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
    {elem, %{env | module_name: module_name}}
  end

  # MODULES INTERACTION
  # ---------------------------------------------------------------------------------------------------

  # {{:., _, [{:__aliases__, _, [module_name]}, fn_name]}, _, args}
  defp process({{:., [line: line], [{:__aliases__, _, mod_names}, fn_name]}, _, args} = elem, env) do
    mod_name = List.last(mod_names)
    if (env[:modules_functions][mod_name][fn_name]) do
      type_of_args_caller = Enum.map(args, fn type -> TypeBuilder.build(type, %{vars: env[:vars], mod_name: env[:module_name], mod_funcs: env[:modules_functions]}) end)
      type_of_args_callee = elem(env[:modules_functions][mod_name][fn_name], 1)

      case TypeComparator.has_type?(type_of_args_caller, :error) or 
            TypeComparator.has_type?(type_of_args_callee, :error) or 
            (TypeComparator.has_type?(type_of_args_caller, :float) and 
            TypeComparator.float_to_int_type?(type_of_args_callee, type_of_args_caller)) or
            TypeComparator.less_or_equal?(type_of_args_caller, type_of_args_callee) === :error do
        true -> {elem, %{env | state: :error, data: {line, "Type error on function call #{mod_name}.#{fn_name}"}}}
        _ -> 
          case TypeComparator.less_or_equal?(type_of_args_caller, type_of_args_callee) do
            true -> {elem, env}
            _ -> 
              case TypeComparator.has_type?(type_of_args_callee, nil) do
                true -> {elem, env}
                _ -> {elem, %{env | state: :error, data: {line, "Type error on function call #{mod_name}.#{fn_name}"}}}
              end
          end
      end
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

  # BINDING
  # ---------------------------------------------------------------------------------------------------

  defp process({:=, [line: line], [operand1, operand2]} = elem, env) do
    type_operand1 = TypeBuilder.build(operand1, %{vars: env[:vars], mod_name: env[:module_name], mod_funcs: env[:modules_functions]})
    type_operand2 = TypeBuilder.build(operand2, %{vars: env[:vars], mod_name: env[:module_name], mod_funcs: env[:modules_functions]})

    case TypeComparator.has_type?(type_operand1, :error) or 
          TypeComparator.has_type?(type_operand2, :error) or 
          (TypeComparator.has_type?(type_operand2, :float) and 
            TypeComparator.float_to_int?(operand1, operand2, %{vars: env[:vars], mod_funcs: env[:modules_functions]})) do
      true -> {elem, %{env | state: :error, data: {line, "Type error on = operator"}}}
      _ -> 
        case TypeComparator.less_or_equal?(type_operand2, type_operand1) do
          :error -> {elem, %{env | state: :error, data: {line, "Type error on = operator"}}}
          true -> 
            case TypeComparator.has_type?(type_operand2, nil) do
              true -> {elem, %{env | data: env[:data] ++ [{line, "Right side of = doesn't have a defined type"}]}}
              _ -> 
                vars = TypeBuilder.add_variables(operand1, type_operand1, operand2, type_operand2, %{vars: env[:vars], mod_funcs: env[:modules_functions]})
                {elem, %{env | vars: vars}}
            end
          _ ->
            vars = TypeBuilder.add_variables(operand1, type_operand1, operand2, type_operand2, %{vars: env[:vars], mod_funcs: env[:modules_functions]})
            {elem, %{env | vars: vars}}
        end
    end
  end

  # NUMBER OPERATORS
  # ---------------------------------------------------------------------------------------------------

  defp process({operator, [line: line], [operand1, operand2]} = elem, env) when (operator in [:*, :+, :/, :-]) do
    type_operand1 = TypeBuilder.build(operand1, %{vars: env[:vars], mod_funcs: env[:modules_functions]})
    type_operand2 = TypeBuilder.build(operand2, %{vars: env[:vars], mod_funcs: env[:modules_functions]})

    case TypeComparator.has_type?(type_operand1, :error) or 
          TypeComparator.has_type?(type_operand2, :error) or 
          (not (TypeComparator.less_or_equal?(type_operand1, :float) and 
            TypeComparator.less_or_equal?(type_operand2, :float))) do
      true -> {elem, %{env | state: :error, data: {line, "Type error on #{Atom.to_string(operator)} operator"}}}
      _ -> 
        case TypeComparator.has_type?(type_operand1, nil) do
          true -> {elem, %{env | data: env[:data] ++ [{line, "Left side of #{Atom.to_string(operator)} doesn't have a defined type"}]}}
          _ -> 
            case TypeComparator.has_type?(type_operand2, nil) do
              true -> {elem, %{env | data: env[:data] ++ [{line, "Right side of #{Atom.to_string(operator)} doesn't have a defined type"}]}}
              _ -> {elem, env}
            end
        end
    end
  end

  # BOOLEAN OPERATORS
  # ---------------------------------------------------------------------------------------------------

  defp process({operator, [line: line], [operand1, operand2]} = elem, env) when (operator in [:and, :or]) do
    type_operand1 = TypeBuilder.build(operand1, %{vars: env[:vars], mod_funcs: env[:modules_functions]})
    type_operand2 = TypeBuilder.build(operand2, %{vars: env[:vars], mod_funcs: env[:modules_functions]})

    case TypeComparator.has_type?(type_operand1, :error) or 
          TypeComparator.has_type?(type_operand2, :error) or 
          (not (TypeComparator.less_or_equal?(type_operand1, :boolean) and 
            TypeComparator.less_or_equal?(type_operand2, :boolean))) do
      true -> {elem, %{env | state: :error, data: {line, "Type error on #{Atom.to_string(operator)} operator"}}}
      _ -> 
        case TypeComparator.has_type?(type_operand1, nil) do
          true -> {elem, %{env | data: env[:data] ++ [{line, "Left side of #{Atom.to_string(operator)} doesn't have a defined type"}]}}
          _ -> 
            case TypeComparator.has_type?(type_operand2, nil) do
              true -> {elem, %{env | data: env[:data] ++ [{line, "Right side of #{Atom.to_string(operator)} doesn't have a defined type"}]}}
              _ -> {elem, env}
            end
        end
    end
  end

  # Not
  defp process({:not, [line: line], [operand]} = elem, env) do
    type_operand = TypeBuilder.build(operand, %{vars: env[:vars], mod_funcs: env[:modules_functions]})

    case TypeComparator.has_type?(type_operand, :error) or  
          (not (TypeComparator.less_or_equal?(type_operand, :boolean))) do
      true -> {elem, %{env | state: :error, data: {line, "Type error on not operator"}}}
      _ -> 
        case TypeComparator.has_type?(type_operand, nil) do
          true -> {elem, %{env | data: env[:data] ++ [{line, "Argument of not doesn't have a defined type"}]}}
          _ -> {elem, env}
        end
    end
  end

  # BASE CASE
  # ---------------------------------------------------------------------------------------------------

  defp process(elem, env), do: {elem, env}
end