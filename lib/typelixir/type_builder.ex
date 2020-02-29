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

  # Variables
  def build({type, _, _}, env), do: env[:vars][type]

  # Literal List
  def build([], _env), do: {:list, nil}

  def build(value, env) when is_list(value) do
    {:list, Enum.map(value, fn t -> build(t, env) end) |> Enum.reduce(fn acc, e -> 
      if e === nil, do: e, else: TypeComparator.greater(acc, e) end)}
  end

  # Literal Tuple 2 Elems
  def build(value, env) when is_tuple(value), do: {:tuple, Enum.map(Tuple.to_list(value), fn t -> build(t, env) end)}

  # Literals
  def build(value, _env) do
    cond do
      is_boolean(value) -> :boolean
      is_bitstring(value) -> :string
      is_integer(value) -> :integer
      is_float(value) -> :float
      is_atom(value) -> :atom
      true -> nil
    end
  end

  # ---------------------------------------------------------------------------------------------------
  
  def from_int_to_float(operand1, operand2, env) do
    vars_to_change = get_vars(operand1, operand2, env)
    if is_list(vars_to_change), do: Enum.filter(vars_to_change, & !is_nil(&1)) |> change_vars(env[:vars]),
      else: Map.replace!(env[:vars], vars_to_change, update_value(env[:vars][vars_to_change]))
  end

  defp get_vars({:%{}, _, list1}, {:%{}, _, list2}, env) do
    Enum.zip(list1, list2)
      |> Enum.map(fn {{_, v1}, {_, v2}} -> get_vars(v1, v2, env) end)
  end

  defp get_vars({var, _, _}, type, env) do
    case TypeComparator.has_type?(env[:vars][var], :integer) do
      true ->
        case TypeComparator.has_type?(build(type, env), :float) do
          true -> var
          _ -> nil
        end
      _ -> nil
    end
  end

  defp get_vars(list1, list2, env) when is_list(list1) do
    Enum.zip(list1, list2)
      |> Enum.map(fn {elem1, elem2} -> get_vars(elem1, elem2, env) end)
  end

  defp get_vars(tuple1, tuple2, env) when is_tuple(tuple1) do
    Enum.zip(Tuple.to_list(tuple1), Tuple.to_list(tuple2))
      |> Enum.map(fn {elem1, elem2} -> get_vars(elem1, elem2, env) end)
  end

  defp get_vars(_ , _, _), do: nil

  defp change_vars([], vars), do: vars

  defp change_vars([head | tail], vars), do: change_vars(tail, Map.replace!(vars, head, update_value(vars[head])))

  defp update_value({:list, type}), do: {:list, update_value(type)}

  defp update_value({:tuple, types_list}), do: {:tuple, Enum.map(types_list, fn type -> update_value(type) end)}

  defp update_value({:map, {key_type, value_type}}), do: {:map, {update_value(key_type), update_value(value_type)}}

  defp update_value(:integer), do: :float

  defp update_value(type), do: type
end