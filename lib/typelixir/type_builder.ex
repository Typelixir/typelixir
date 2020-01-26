defmodule TypeBuilder do
  def build({:list, _, [type]}, vars), do: {:list, build(type, vars)}

  def build({:tuple, _, [types_list]}, vars), do: {:tuple, Enum.map(types_list, fn type -> build(type, vars) end)}

  def build({:map, _, [key_type, value_type]}, vars), do: {:map, {build(key_type, vars), build(value_type, vars)}}

  def build({:_, _, _}, _vars), do: nil

  def build({type, _, _}, _vars) when (type in [:string, :boolean, :integer, :float, :atom]), do: type

  # Literal Tuple More Than 2 Elems
  def build({:{}, _, list}, vars), do: {:tuple, Enum.map(list, fn t -> build(t, vars) end)}

  # Literal Map
  def build({:%{}, _, list}, vars) do
    {:map,
      Enum.map(list, fn {key, elem} -> {build(key, vars), build(elem, vars)} end)
      |> Enum.reduce(fn {k_acc, v_acc}, {k_e, v_e} -> {TypeComparator.greater(k_acc, k_e), TypeComparator.greater(v_acc, v_e)}
      end)
    }
  end

  # Variables
  def build({type, _, _}, vars), do: vars[type]

  # Literal List
  def build([], _vars), do: {:list, nil}

  def build(value, vars) when is_list(value) do
    {:list, Enum.map(value, fn t -> build(t, vars) end) |> Enum.reduce(fn acc, e -> TypeComparator.greater(acc, e) end)}
  end

  # Literal Tuple 2 Elems
  def build(value, vars) when is_tuple(value), do: {:tuple, Enum.map(Tuple.to_list(value), fn t -> build(t, vars) end)}

  # Literals
  def build(value, _vars) do
    cond do
      is_boolean(value) -> :boolean
      is_bitstring(value) -> :string
      is_integer(value) -> :integer
      is_float(value) -> :float
      is_atom(value) -> :atom
      true -> nil
    end
  end
end