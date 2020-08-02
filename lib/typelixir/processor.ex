defmodule Typelixir.Processor do
  @moduledoc false

  alias Typelixir.{PatternBuilder, TypeComparator, PreProcessor, Utils}

  # FIRST
  # ---------------------------------------------------------------------------------------------------

  def process_file(path, env) do
    ast = Code.string_to_quoted(File.read!(Path.absname(path)))

    # while developing to see the info in the console
    IO.puts "#{path} ast:"
    IO.inspect ast

    {_ast, result} = Macro.prewalk(ast, env, &process(&1, &2))
    Utils.prepare_result_data(result)
  end

  # BASE CASES
  # ---------------------------------------------------------------------------------------------------

  # error
  defp process(elem, %{
    state: :error,
    type: _,
    error_data: _,
    warnings: _,
    data: _,
    prefix: _,
    vars: _,
    functions: _
  } = env), do: {elem, env}

  # block
  defp process({:__block__, _, _} = elem, env), do: {elem, env}

  # IMPORT
  # ---------------------------------------------------------------------------------------------------

  defp process({:import, [line: line], [{:__aliases__, _, module_name_ext}]}, env) do
    elem = {:import, [line: line], []}

    module_name = 
      module_name_ext 
      |> Enum.map(fn name -> Atom.to_string(name) end) 
      |> Enum.join(".")

    case env[:functions][module_name] do
      nil -> {elem, env}
      _ -> {elem, %{env | functions: Map.put(env[:functions], env[:prefix], Map.merge(env[:functions][env[:prefix]], env[:functions][module_name]))}}
    end
  end

  # ALIAS
  # ---------------------------------------------------------------------------------------------------

  defp process({:alias, [line: line], [{:__aliases__, _, module_name_ext}]}, env) do
    elem = {:alias, [line: line], []}

    module_name = 
      module_name_ext 
      |> Enum.map(fn name -> Atom.to_string(name) end) 
      |> Enum.join(".")

    case env[:functions][module_name] do
      nil -> {elem, env}
      _ -> {elem, %{env | functions: Map.put(env[:functions], Atom.to_string(Enum.at(module_name_ext, -1)), env[:functions][module_name])}}
    end
  end

  defp process({:alias, [line: line], [{:__aliases__, _, module_name_ext}, [as: {:__aliases__, _, as_module_name_ext}]]}, env) do
    elem = {:alias, [line: line], []}

    module_name = 
      module_name_ext 
      |> Enum.map(fn name -> Atom.to_string(name) end) 
      |> Enum.join(".")
    
    as_module_name = 
      as_module_name_ext 
      |> Enum.map(fn name -> Atom.to_string(name) end) 
      |> Enum.join(".")

    case env[:functions][module_name] do
      nil -> {elem, env}
      _ -> {elem, %{env | functions: Map.put(env[:functions], as_module_name, env[:functions][module_name])}}
    end
  end

  # DEFMODULE
  # ---------------------------------------------------------------------------------------------------

  defp process({:defmodule, [line: line], [{:__aliases__, meta, module_name}, [do: block]]}, env) do
    elem = {:defmodule, [line: line], [{:__aliases__, meta, module_name}, [do: {:__block__, [], []}]]}
    
    name = 
      module_name 
      |> Enum.map(fn name -> Atom.to_string(name) end) 
      |> Enum.join(".")
    new_mod_name = if env[:prefix], do: env[:prefix] <> "." <> name, else: name
    
    {_ast, result} = Macro.prewalk(block, %{env | vars: %{}, prefix: new_mod_name}, &process(&1, &2)) 
    result = Utils.prepare_result_data(result)

    {elem, result}
  end

  # FUNCTIONS DEF
  # ---------------------------------------------------------------------------------------------------

  defp process({:@, [line: line], [{:spec, _, [{:::, _, [{_fn_name, _, _type_of_args}, _type_of_return]}]}]}, env) do
    elem = {:@, [line: line], []}
    {elem, env}
  end

  defp process({defs, [line: line], [{function_name, _meta, params}, [do: block]]}, env) when (defs in [:def, :defp]) do
    elem = {defs, [line: line], []}
    
    params_length = length(params)
    fn_key = {function_name, params_length}

    case env[:functions][env[:prefix]][fn_key] do
      nil ->
        {_ast, result} = Macro.prewalk(block, %{env | vars: %{}}, &process(&1, &2))
        result = Utils.prepare_result_data(result)

        {elem, result}
      _ -> 
        return_type = env[:functions][env[:prefix]][fn_key] |> elem(0)
        param_type_list = env[:functions][env[:prefix]][fn_key] |> elem(1)
        params_vars = PatternBuilder.vars(params, param_type_list)

        case params_vars do
          {:error, msg} -> Utils.return_error(elem, env, {line, msg})
          _ ->
            {_ast, result} = Macro.prewalk(block, %{env | vars: params_vars}, &process(&1, &2))
            result = Utils.prepare_result_data(result)
            
            case result[:state] do
              :error -> {elem, result}
              _ ->
                case TypeComparator.subtype?(result[:type], return_type) do
                  :error -> Utils.return_error(elem, result, {line, "Body doesn't match function type on #{function_name}/#{params_length} declaration"})
                  _ -> {elem, result}
                end
            end
        end
    end
  end

  # FUNCTIONS CALL
  # ---------------------------------------------------------------------------------------------------

  defp process({{:., [line: line], [{:__aliases__, [line: line], mod_names}, fn_name]}, [line: line], args}, env) do
    elem = {{:., [line: line], [{:__aliases__, [line: line], []}, fn_name]}, [line: line], []} 
    function_call_process(elem, line, mod_names, fn_name, args, env)
  end

  # BINDING
  # ---------------------------------------------------------------------------------------------------

  defp process({:=, [line: line], [pattern, expression]}, env) do
    elem = {:=, [line: line], []}

    {_ast, result} = Macro.prewalk(expression, env, &process(&1, &2))
    result = Utils.prepare_result_data(result)
    
    case result[:state] do
      :error -> {elem, result}
      _ -> 
        pattern = if is_list(pattern), do: pattern, else: [pattern]
        pattern_vars = PatternBuilder.vars(pattern, [result[:type]])

        case pattern_vars do
          {:error, msg} -> Utils.return_error(elem, env, {line, msg})
          _ -> Utils.return_merge_vars(elem, result, pattern_vars)
        end
    end
  end

  # NUMBER OPERATORS
  # ---------------------------------------------------------------------------------------------------

  defp process({operator, [line: line], [operand1, operand2]}, env) when (operator in [:*, :+, :-]) do
    elem = {operator, [line: line], []}
    binary_operator_process(elem, env, line, operator, operand1, operand2, :integer, :float, false, false, false)
  end

  defp process({:/, [line: line], [operand1, operand2]}, env) do
    elem = {:/, [line: line], []}
    binary_operator_process(elem, env, line, :/, operand1, operand2, :integer, :float, true, false, false)
  end

  # neg
  defp process({:-, [line: line], [operand]}, env) do
    elem = {:-, [line: line], []}
    unary_operator_process(elem, env, line, :-, operand, :integer, :float, [:any])
  end

  # BOOLEAN OPERATORS
  # ---------------------------------------------------------------------------------------------------

  defp process({operator, [line: line], [operand1, operand2]}, env) when (operator in [:and, :or]) do
    elem = {operator, [line: line], []}
    binary_operator_process(elem, env, line, operator, operand1, operand2, :boolean, :boolean, false, false, false)
  end

  # not
  defp process({:not, [line: line], [operand]}, env) do
    elem = {:not, [line: line], []}
    unary_operator_process(elem, env, line, :not, operand, :boolean, :boolean, [:any])
  end

  # COMPARISON OPERATORS
  # ---------------------------------------------------------------------------------------------------

  defp process({operator, [line: line], [operand1, operand2]}, env) when (operator in [:==, :!=, :>, :<, :<=, :>=, :===, :!==]) do
    elem = {operator, [line: line], []}
    binary_operator_process(elem, env, line, operator, operand1, operand2, :boolean, :any, false, true, false)
  end

  # LIST OPERATORS
  # ---------------------------------------------------------------------------------------------------

  defp process({operator, [line: line], [operand1, operand2]}, env) when operator in [:++, :--] do
    elem = {operator, [line: line], []}
    binary_operator_process(elem, env, line, operator, operand1, operand2, {:list, :any}, {:list, :any}, false, false, false)
  end

  # STRING OPERATORS
  # ---------------------------------------------------------------------------------------------------

  defp process({:<>, [line: line], [operand1, operand2]}, env) do
    elem = {:<>, [line: line], []}
    binary_operator_process(elem, env, line, :<>, operand1, operand2, :string, :string, false, false, false)
  end

  # IF/UNLESS
  # ---------------------------------------------------------------------------------------------------

  defp process({operator, [line: line], [condition, [do: do_block]]}, env) when operator in [:if, :unless] do
    elem = {operator, [line: line], []}
    
    {_ast, result_condition} = Macro.prewalk(condition, env, &process(&1, &2))
    result_condition = Utils.prepare_result_data(result_condition)
    
    case result_condition[:state] do
      :error -> {elem, result_condition}
      _ ->
        case TypeComparator.subtype?(result_condition[:type], :boolean) do
          :error -> Utils.return_error(elem, env, {line, "Type error on #{Atom.to_string(operator)} condition"})
          _ -> 
            {_ast, result_do_block} = Macro.prewalk(do_block, result_condition, &process(&1, &2))
            result_do_block = Utils.prepare_result_data(result_do_block)

            case result_do_block[:state] do
              :error -> {elem, result_do_block}
              _ -> Utils.return_merge_vars(elem, %{env | type: result_do_block[:type]}, result_condition[:vars])
            end
        end
    end
  end

  defp process({operator, [line: line], [condition, [do: do_block, else: else_block]]}, env) when operator in [:if, :unless] do
    elem = {operator, [line: line], []}
    
    {_ast, result_condition} = Macro.prewalk(condition, env, &process(&1, &2))
    result_condition = Utils.prepare_result_data(result_condition)
    
    case result_condition[:state] do
      :error -> {elem, result_condition}
      _ ->
        {_ast, result_do_block} = Macro.prewalk(do_block, result_condition, &process(&1, &2))
        result_do_block = Utils.prepare_result_data(result_do_block)
        
        case TypeComparator.subtype?(result_condition[:type], :boolean) do
          :error -> Utils.return_error(elem, env, {line, "Type error on #{Atom.to_string(operator)} condition"})
          _ -> 
            case result_do_block[:state] do
              :error -> {elem, result_do_block}
              _ -> 
                {_ast, result_else_block} = Macro.prewalk(else_block, result_condition, &process(&1, &2))
                result_else_block = Utils.prepare_result_data(result_else_block)
                
                case result_else_block[:state] do
                  :error -> {elem, result_else_block}
                  _ ->
                    case TypeComparator.supremum(result_do_block[:type], result_else_block[:type]) do
                      :error -> Utils.return_error(elem, env, {line, "Type error on #{Atom.to_string(operator)} branches"})
                      type -> Utils.return_merge_vars(elem, %{env | type: type}, result_condition[:vars])
                    end
                end
            end
        end 
    end
  end

  # COND 
  # ---------------------------------------------------------------------------------------------------
  
  defp process({:cond, [line: line], [[do: branches]]}, env) do
    elem = {:cond, [line: line], []}

    Enum.reduce_while(branches, {elem, %{env | type: :any}}, 
      fn {:->, [line: line], [[condition], do_block]}, {elem, acc_env} ->
        {_ast, result_condition} = Macro.prewalk(condition, acc_env, &process(&1, &2))
        result_condition = Utils.prepare_result_data(result_condition)
        
        case result_condition[:state] do
          :error -> {:halt, {elem, result_condition}}
          _ ->
            case TypeComparator.subtype?(result_condition[:type], :boolean) do
              :error -> {:halt, Utils.return_error(elem, acc_env, {line, "Type error on cond condition"})}
              _ -> 
                {_ast, result_do_block} = Macro.prewalk(do_block, result_condition, &process(&1, &2))
                result_do_block = Utils.prepare_result_data(result_do_block)

                case result_do_block[:state] do
                  :error -> {:halt, {elem, result_do_block}}
                  _ -> 
                    case TypeComparator.supremum(result_do_block[:type], acc_env[:type]) do
                      :error -> {:halt, Utils.return_error(elem, acc_env, {line, "Type error on cond branches"})}
                      type -> {:cont, {elem, %{acc_env | type: type}}}
                    end
                end
            end
        end
      end)
  end

  # CASE
  # ---------------------------------------------------------------------------------------------------

  defp process({:case, [line: line], [condition, [do: branches]]}, env) do
    elem = {:case, [line: line], []}

    {_ast, result_condition} = Macro.prewalk(condition, env, &process(&1, &2))
    result_condition = Utils.prepare_result_data(result_condition)
        
    case result_condition[:state] do
      :error -> {elem, result_condition}
      _ ->
        Enum.reduce_while(branches, {elem, %{env | vars: Map.merge(env[:vars], result_condition[:vars]), type: :any}}, 
          fn {:->, [line: line], [[pattern], do_block]}, {elem, acc_env} ->
            pattern = if is_list(pattern), do: pattern, else: [pattern]
            pattern_vars = PatternBuilder.vars(pattern, [result_condition[:type]])

            case pattern_vars do
              {:error, msg} -> {:halt, Utils.return_error(elem, env, {line, msg})}
              _ -> 
                {_ast, result_do_block} = Macro.prewalk(do_block, %{acc_env | vars: Map.merge(acc_env[:vars], pattern_vars)}, &process(&1, &2))
                result_do_block = Utils.prepare_result_data(result_do_block)

                case result_do_block[:state] do
                  :error -> {:halt, {elem, result_do_block}}
                  _ ->
                    case TypeComparator.supremum(result_do_block[:type], acc_env[:type]) do
                      :error -> {:halt, Utils.return_error(elem, acc_env, {line, "Type error on case branches"})}
                      type -> {:cont, {elem, %{acc_env | type: type}}}
                    end
                end
            end
          end)
    end
  end

  # LITERAL, VARIABLE, TUPLE, LIST, MAP
  # ---------------------------------------------------------------------------------------------------

  # tuple more 2 elems
  defp process({:{}, [line: line], list}, env) do
    elem = {:{}, [line: line], []}
    
    {types_list, result} = 
      Enum.map(list, fn t -> elem(Macro.prewalk(t, env, &process(&1, &2)), 1) end)
      |> Enum.reduce_while({[], env}, fn result, {types_list, env_acc} ->
          result = Utils.prepare_result_data(result)
          
          case result[:state] do
            :error -> {:halt, {[], result}}
            _ -> {:cont, {types_list ++ [result[:type]], elem(Utils.return_merge_vars(elem, env_acc, result[:vars]), 1)}}
          end
        end)

    {{:{}, [line: line], []}, %{result | type: {:tuple, types_list}}}
  end

  # map
  defp process({:%{}, _, []} = elem, env), do: {elem, %{env | type: PatternBuilder.type(elem, env)}}

  defp process({:%{}, [line: line], list}, env) do
    elem = {:%{}, [line: line], []}
    
    list = Enum.sort(list)
    keys = Enum.map(list, fn {k, _} -> k end)
    values = Enum.map(list, fn {_, v} -> v end)

    {type_key, result_key} = 
      Enum.map(keys, fn t -> elem(Macro.prewalk(t, env, &process(&1, &2)), 1) end)
      |> Enum.reduce_while({:any, env}, fn result, {type_acc, env_acc} ->
          result = Utils.prepare_result_data(result)
          
          case result[:state] do
            :error -> {:halt, {:any, result}}
            _ -> 
              case TypeComparator.supremum(result[:type], type_acc) do
                :error -> {:halt, Utils.return_error(elem, env, {line, "Malformed type map"})}
                type -> {:cont, {type, elem(Utils.return_merge_vars([], env_acc, result[:vars]), 1)}}
              end
          end
        end)

    case result_key[:state] do
      :error -> {elem, result_key}
      _ -> 
        {types_values, result_value} = 
          Enum.map(values, fn t -> elem(Macro.prewalk(t, env, &process(&1, &2)), 1) end)
          |> Enum.reduce_while({[], env}, fn result, {types_list, env_acc} ->
              result = Utils.prepare_result_data(result)
              
              case result[:state] do
                :error -> {:halt, {[], result}}
                _ -> {:cont, {types_list ++ [result[:type]], elem(Utils.return_merge_vars(elem, env_acc, result[:vars]), 1)}}
              end
            end)

        {elem, %{result_value | type: {:map, {type_key, types_values}}, vars: Map.merge(result_key[:vars], result_value[:vars])}}
    end
  end

  # map app
  defp process({{:., [line: line], [Access, :get]}, meta, [map, key]}, env) do
    elem = {{:., [line: line], [Access, :get]}, meta, []}
    map_app_process(elem, line, map, key, env)
  end

  defp process({{:., [line: line], [map, key]}, meta, []}, env) do
    elem = {{:., [line: line], []}, meta, []}
    map_app_process(elem, line, map, key, env)
  end

  # variables or local function
  defp process({value, [line: line], params}, env) do
    elem = {value, [line: line], []}
    case env[:vars][value] do
      nil ->
        if (env[:prefix] !== nil and is_list(params) and env[:functions][env[:prefix]][{value, length(params)}] !== nil) do
          function_call_process(elem, line, [String.to_atom(env[:prefix])], value, params, env)
        else
          {elem, %{env | type: :any}} 
        end
      type -> {elem, %{env | type: type}}
    end
  end

  # list
  defp process([] = elem, env), do: {elem, %{env | type: PatternBuilder.type(elem, env)}}

  defp process([{:|, [line: line], [operand1, operand2]}], env) do
    elem = {:|, [line: line], []}
    binary_operator_process(elem, env, line, :|, operand1, operand2, {:list, :any}, {:list, :any}, false, false, true)
  end

  defp process(elem, env) when is_list(elem) do
    {type, result} = 
      Enum.map(elem, fn t -> elem(Macro.prewalk(t, env, &process(&1, &2)), 1) end)
      |> Enum.reduce_while({:any, env}, fn result, {type_acc, env_acc} ->
          result = Utils.prepare_result_data(result)
          
          case result[:state] do
            :error -> {:halt, {:any, result}}
            _ -> 
              case TypeComparator.supremum(result[:type], type_acc) do
                :error -> {:halt, Utils.return_error(elem, env, {"", "Malformed type list"})} # line? :(
                type -> {:cont, {type, elem(Utils.return_merge_vars([], env_acc, result[:vars]), 1)}}
              end
          end
        end)

    {[], %{result | type: {:list, type}}}
  end

  # tuple 2 elems
  defp process({elem1, elem2} = elem, env) when (elem1 !== :ok) do
    {types_list, result} = 
      Enum.map([elem1, elem2], fn t -> elem(Macro.prewalk(t, env, &process(&1, &2)), 1) end)
      |> Enum.reduce_while({[], env}, fn result, {types_list, env_acc} ->
          result = Utils.prepare_result_data(result)
          
          case result[:state] do
            :error -> {:halt, {[], result}}
            _ -> {:cont, {types_list ++ [result[:type]], elem(Utils.return_merge_vars(elem, env_acc, result[:vars]), 1)}}
          end
        end)

    {{}, %{result | type: {:tuple, types_list}}}
  end

  # literals
  defp process(elem, env), do: {elem, %{env | type: PatternBuilder.type(elem, env)}}

  # OTHERS
  # ---------------------------------------------------------------------------------------------------

  defp function_call_process(elem, line, mod_names, fn_name, args, env) do
    mod_name = 
      mod_names 
        |> Enum.map(fn name -> Atom.to_string(name) end) 
        |> Enum.join(".")
    spec_type = env[:functions][mod_name][{fn_name, length(args)}]

    if (spec_type) do
      {result_type, type_args} = spec_type

      args_check = Enum.reduce_while(Enum.zip(args, type_args), env, 
        fn {arg, type}, acc_env ->
          {_ast, result} = Macro.prewalk(arg, acc_env, &process(&1, &2))
          result = Utils.prepare_result_data(result)
          
          case TypeComparator.subtype?(result[:type], type) do
            true -> {:cont, Map.merge(acc_env, result)}
            _ -> 
              # ver casos para imprimir bien variables, literales, etc
              {:halt, %{acc_env | state: :error, error_data: Map.put(acc_env[:error_data], line, "Argument #{inspect arg} does not have type #{Atom.to_string(type)}")}}
          end
        end)
      
      case args_check[:state] do
        :error -> {elem, args_check}
        _ -> {elem, %{args_check | type: result_type}}
      end
    else
      args_check = Enum.reduce(args, env, 
        fn arg, acc_env ->
          {_ast, result} = Macro.prewalk(arg, acc_env, &process(&1, &2))
          Map.merge(acc_env, Utils.prepare_result_data(result))
        end)

      case args_check[:state] do
        :error -> {elem, args_check}
        _ -> {elem, %{args_check | type: :any}}
      end
    end
  end

  defp unary_operator_process(elem, env, line, operator, operand, min_type, max_type, any_type) do
    {_ast, result} = Macro.prewalk(operand, env, &process(&1, &2))
    result = Utils.prepare_result_data(result)
    
    case result[:state] do
      :error -> {elem, result}
      _ ->
        case TypeComparator.subtype?(result[:type], max_type) do
          :error -> Utils.return_error(elem, env, {line, "Type error on #{Atom.to_string(operator)} operator"})
          false -> 
            cond do
              result[:type] in any_type -> {elem, %{result | type: min_type}}
              true -> Utils.return_error(elem, env, {line, "Type error on #{Atom.to_string(operator)} operator"})
            end
          true -> {elem, result}
        end
    end
  end

  defp binary_operator_process(elem, env, line, operator, operand1, operand2, min_type, max_type, is_division, is_comparison, is_list) do
    {_ast, result_op1} = Macro.prewalk(operand1, env, &process(&1, &2))
    result_op1 = Utils.prepare_result_data(result_op1)
    
    case result_op1[:state] do
      :error -> {elem, result_op1}
      _ ->
        {_ast, result_op2} = Macro.prewalk(operand2, env, &process(&1, &2))
        result_op2 = Utils.prepare_result_data(result_op2)

        case result_op2[:state] do
          :error -> {elem, result_op2}
          _ ->
            cond do
              is_comparison -> Utils.return_merge_vars(elem, %{result_op1 | type: :boolean}, result_op2[:vars])
              true ->
                type = 
                  cond do
                    is_list and is_tuple(result_op2[:type]) -> TypeComparator.supremum({:list, result_op1[:type]}, result_op2[:type])
                    is_list -> {:list, TypeComparator.supremum(result_op1[:type], result_op2[:type])}
                    true -> TypeComparator.supremum(result_op1[:type], result_op2[:type])
                  end
                
                cond do
                  TypeComparator.has_type?(type, :error) === true -> Utils.return_error(elem, env, {line, "Type error on #{Atom.to_string(operator)} operator"})
                  type === :any -> Utils.return_merge_vars(elem, %{result_op1 | type: min_type}, result_op2[:vars])
                  true ->
                    case TypeComparator.subtype?(type, max_type) do
                      true -> 
                        cond do
                          is_division -> Utils.return_merge_vars(elem, %{result_op1 | type: :float}, result_op2[:vars])
                          true -> Utils.return_merge_vars(elem, %{result_op1 | type: type}, result_op2[:vars])
                        end
                      _ -> Utils.return_error(elem, env, {line, "Type error on #{Atom.to_string(operator)} operator"})
                    end
                end
            end
        end
    end
  end

  defp map_app_process(elem, line, map, key, env) do
    {_ast, result_map} = Macro.prewalk(map, env, &process(&1, &2))
    result_map = Utils.prepare_result_data(result_map)

    case result_map[:state] do
      :error -> {elem, result_map}
      _ -> 
        {_ast, result_key} = Macro.prewalk(key, env, &process(&1, &2))
        result_key = Utils.prepare_result_data(result_key)

        case result_key[:state] do
          :error -> {elem, result_key}
          _ -> 
            case result_map[:type] do
              {:map, {key_type, _value_types}} ->
                case TypeComparator.subtype?(result_key[:type], key_type) do
                  true -> Utils.return_merge_vars(elem, %{result_map | type: :any}, result_key[:vars])
                  _ -> Utils.return_error(elem, env, {line, "Expected #{key_type} as key instead of #{result_key[:type]}"})
                end
              _ -> Utils.return_error(elem, env, {line, "#{inspect map} is not a map"}) # ver casos para imprimir bien variables, literales, etc
            end
        end
    end
  end
end