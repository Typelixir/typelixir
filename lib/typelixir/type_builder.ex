defmodule TypeBuilder do
  def build({:list, _, [type]}), do: {:list, build(type)}

  def build({:tuple, _, [types_list]}), do: {:tuple, Enum.map(types_list, fn type -> build(type) end)}

  def build({:map, _, [key_type, value_type]}), do: {:map, {build(key_type), build(value_type)}}

  def build({:_, _, _}), do: nil

  def build({type, _, _}) when (type in [:string, :boolean, :integer, :float, :atom]), do: type

  # Literal Tuple More Than 2 Elems
  def build({:{}, _, list}), do: {:tuple, Enum.map(list, fn t -> build(t) end)}

  # Literal Map
  def build({:%{}, _, list}) do
    {:map,
      Enum.map(list, fn {key, elem} -> {build(key), build(elem)} end)
      |> Enum.reduce(fn {k_acc, v_acc}, {k_e, v_e} -> {TypeComparator.greater(k_acc, k_e), TypeComparator.greater(v_acc, v_e)}
      end)
    }
  end

  # Literal List
  def build([]), do: {:list, nil}

  def build(value) when is_list(value) do
    {:list, Enum.map(value, fn t -> build(t) end) |> Enum.reduce(fn acc, e -> TypeComparator.greater(acc, e) end)}
  end

  # Literal Tuple 2 Elems
  def build(value) when is_tuple(value), do: {:tuple, Enum.map(Tuple.to_list(value), fn t -> build(t) end)}

  # Literals
  def build(value) do
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