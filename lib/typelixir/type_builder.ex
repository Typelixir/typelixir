defmodule Typelixir.TypeBuilder do

  alias Typelixir.TypeComparator

  # ---------------------------------------------------------------------------------------------------
  # build -> returns the type of any expression

  @operators [:*, :+, :/, :-, :and, :or, :not, :++, :--, :<>]
  @comparison_operators [:==, :!=, :===, :!==, :>, :<, :>=, :<=]

  def build({:list, _, [type]}, env), do: {:list, build(type, env)}

  def build({:tuple, _, [types_list]}, env), do: {:tuple, Enum.map(types_list, fn type -> build(type, env) end)}

  def build({:map, _, [key_type, value_type]}, env), do: {:map, {build(key_type, env), build(value_type, env)}}

  def build({:_, _, _}, _env), do: nil

  def build({type, _, _}, _env) when (type in [:string, :boolean, :integer, :float, :atom]), do: type

  # Literal Tuple More Than 2 Elems
  def build({:{}, _, list}, env), do: {:tuple, Enum.map(list, fn t -> build(t, env) end)}

  # Literal Map
  def build({:%{}, _, []}, env), do: {:map, {nil, nil}}

  def build({:%{}, _, list}, env) do
    {:map,
      Enum.map(list, fn {key, elem} -> {build(key, env), build(elem, env)} end)
      |> Enum.reduce(fn {k_acc, v_acc}, {k_e, v_e} -> {TypeComparator.greater(k_acc, k_e), TypeComparator.greater(v_acc, v_e)}
      end)
    }
  end

  # Functions
  def build({{:., _, [{:__aliases__, _, mod_names}, fn_name]}, _, _}, env) do
    mod_name = List.last(mod_names)
    type = env[:mod_funcs][mod_name][fn_name]
    case type do
      nil -> nil
      _ -> elem(type, 0)
    end
  end

  # Operators
  def build({operator, _, operands}, env) when (operator in @operators) do
    Enum.map(operands, fn t -> build(t, env) end) |> Enum.reduce(fn acc, e -> TypeComparator.greater(acc, e) end)
  end

  # Comparison perators
  def build({operator, _, operands}, env) when (operator in @comparison_operators) do
    type_comparison = Enum.map(operands, fn t -> build(t, env) end) |> Enum.reduce(fn acc, e -> TypeComparator.greater(acc, e) end)
    case type_comparison do
      :error -> :error
      _ -> :boolean
    end
  end

  # Variables or function defined on the compiling module
  def build({type, _, _}, env) do
    case env[:vars][type] do
      nil -> 
        case env[:mod_funcs][env[:mod_name]][type] do
          nil -> nil
          type -> elem(type, 0)
        end
      type -> type
    end
  end

  # Literal List
  def build([], _env), do: {:list, nil}

  def build(value, env) when is_list(value) do
    {:list, Enum.map(value, fn t -> build(t, env) end) |> Enum.reduce(fn acc, e -> TypeComparator.greater(acc, e) end)}
  end

  # Literal Tuple 2 Elems
  def build(value, env) when is_tuple(value), do: {:tuple, Enum.map(Tuple.to_list(value), fn t -> build(t, env) end)}

  # Literals
  def build(value, _env) do
    cond do
      value === nil -> nil
      is_boolean(value) -> :boolean
      is_bitstring(value) -> :string
      is_integer(value) -> :integer
      is_float(value) -> :float
      is_atom(value) -> :atom
      true -> nil
    end
  end

  # ---------------------------------------------------------------------------------------------------
  # add_variables -> returns a new environment with the vars of pattern1 and the types of pattern2 (used by binding)

  def add_variables(_, _, _, nil, env), do: env[:vars]

  def add_variables({op1, _, _}, nil, _, type_op2, env), do: Map.put(env[:vars], op1, type_op2)

  # List
  def add_variables(op1, {:list, _}, op2, {:list, _}, env) do
    Enum.reduce(Enum.zip(op1, op2), env[:vars], 
      fn {op1, op2}, acc ->
        add_variables(op1, build(op1, env), op2, build(op2, env), %{env | vars: acc})
      end)
  end

  # Tuple
  def add_variables({:{}, _, op1}, {:tuple, _}, {:{}, _, op2}, {:tuple, _}, env) do
    Enum.reduce(Enum.zip(op1, op2), env[:vars], 
      fn {op1, op2}, acc ->
        add_variables(op1, build(op1, env), op2, build(op2, env), %{env | vars: acc})
      end)
  end

  def add_variables(op1, {:tuple, _}, op2, {:tuple, _}, env) do
    Enum.reduce(Enum.zip(Tuple.to_list(op1), Tuple.to_list(op2)), env[:vars], 
      fn {op1, op2}, acc ->
        add_variables(op1, build(op1, env), op2, build(op2, env), %{env | vars: acc})
      end)
  end

  # Map
  def add_variables({:%{}, _, op1}, {:map, _}, {:%{}, _, op2}, {:map, _}, env) do
    Enum.reduce(Enum.zip(op1, op2), env[:vars], 
      fn {op1, op2}, acc ->
        add_variables(op1, build(op1, env), op2, build(op2, env), %{env | vars: acc})
      end)
  end

  def add_variables(_, _, _, _, env), do: env[:vars]

  # ---------------------------------------------------------------------------------------------------
  # get_new_vars_env -> returns a new map with the vars of params and the corresponding types of 
  # param_type_list (used by function definition)

  def get_new_vars_env(params, param_type_list) do
    new_vars = Enum.zip(params, param_type_list) |> Enum.map(fn {var, type} -> get_new_vars(var, type) end) |> List.flatten()
    case Enum.member?(new_vars, :error) do
      true -> :error
      _ -> 
        Enum.reduce(new_vars, %{}, fn {var, type}, acc -> Map.put(acc, var, type) end)
    end
  end

  # List
  defp get_new_vars(op, {:list, type}) when is_list(op), do: Enum.map(op, fn x -> get_new_vars(x, type) end)

  defp get_new_vars(_, nil), do: []

  defp get_new_vars({op, _, _}, type) when (op not in [:{}, :%{}]), do: {op, type}

  # Tuple
  defp get_new_vars({:{}, _, ops}, {:tuple, type_list}) do 
    if length(ops) === length(type_list), do: Enum.zip(ops, type_list) |> Enum.map(fn {var, type} -> get_new_vars(var, type) end),
    else: :error
  end

  defp get_new_vars(ops, {:tuple, type_list}) do
    ops = Tuple.to_list(ops)
    if length(ops) === length(type_list), do: Enum.zip(ops, type_list) |> Enum.map(fn {var, type} -> get_new_vars(var, type) end),
    else: :error
  end

  # Map
  defp get_new_vars({:%{}, _, op}, {:map, {_, value_type}}) do
    (Enum.map(op, fn {_, value} -> value end) |> Enum.map(fn x -> get_new_vars(x, value_type) end))
  end

  defp get_new_vars(_, _), do: :error
end