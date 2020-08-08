defmodule Typelixir.TypeComparator do
  # ---------------------------------------------------------------------------------------------------
  # supremum -> returns the supremum between type1 and type2

  def supremum(list_type) when is_list(list_type), do: Enum.reduce(list_type, fn acc, e -> supremum(acc, e) end)
  
  def supremum(type1, type2) when type1 === type2, do: type1

  def supremum(list_type1, list_type2) when is_list(list_type1) and is_list(list_type2), 
    do: Enum.zip(list_type1, list_type2) |> Enum.map(fn {x, y} -> supremum(x, y) end)

  def supremum({:map, {key_type1, list_value_type1}}, {:map, {key_type2, list_value_type2}}), do: 
    if (length(list_value_type1) >= length(list_value_type2)), do: 
      {:map, {supremum(key_type1, key_type2), supremum(list_value_type1, list_value_type2)}}, else: :error

  def supremum({:tuple, list_type1}, {:tuple, list_type2}), do:
    if (length(list_type1) === length(list_type2)), do: {:tuple, supremum(list_type1, list_type2)}, else: :error

  def supremum({:list, type1}, {:list, type2}), do: {:list, supremum(type1, type2)}

  def supremum(:integer, :float), do: :float
  
  def supremum(:float, :integer), do: :float

  # -- downcast
  def supremum(:any, type), do: type

  def supremum(type, :any), do: type
  # --

  def supremum(:none, type), do: type

  def supremum(type, :none), do: type

  def supremum(:error, _), do: :error

  def supremum(_, :error), do: :error

  def supremum(_, _), do: :error

  # ---------------------------------------------------------------------------------------------------
  # has_type? -> returns true if type1 contains type2

  def has_type?(list_type, type) when is_list(list_type) do
    Enum.map(list_type, fn t -> has_type?(t, type) end) |> Enum.member?(true)
  end

  def has_type?({:map, {key_type, list_value_type}}, type), 
    do: has_type?(key_type, type) or has_type?(list_value_type, type)

  def has_type?({:tuple, list_type}, type), do: has_type?(list_type, type)

  def has_type?({:list, list_type}, type), do: has_type?(list_type, type)

  def has_type?(type1, type2) when type1 === type2, do: true

  def has_type?(_, _), do: false
end