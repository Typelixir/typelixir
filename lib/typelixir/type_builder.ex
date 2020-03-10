defmodule Typelixir.TypeBuilder do

  alias Typelixir.TypeComparator

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
  def build({operator, _, operands}, env) when (operator in [:*, :+, :/, :-, :and, :or, :not]) do
    Enum.map(operands, fn t -> build(t, env) end) |> Enum.reduce(fn acc, e -> TypeComparator.greater(acc, e) end)
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
end