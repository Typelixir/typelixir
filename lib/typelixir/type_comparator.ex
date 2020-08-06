defmodule Typelixir.TypeComparator do
  # ---------------------------------------------------------------------------------------------------
  # subtype? -> returns true if type1 is subtype of type2

  def subtype?(list_type) when (is_list(list_type)) do
    types = Enum.map(list_type, fn {type1, type2} -> subtype?(type1, type2) end)
    if Enum.member?(types, :error), do: :error, else: not Enum.member?(types, false)
  end

  def subtype?(type1, type2) when type1 === type2, do: true

  def subtype?({:map, {key_type1, list_value_type1}}, {:map, {key_type2, list_value_type2}}) do 
    if length(list_value_type1) >= length(list_value_type2) do
      case subtype?(Enum.zip(list_value_type1, list_value_type2)) do
        :error -> :error
        value_result ->
          case subtype?(key_type2, key_type1) do
            :error -> :error
            key_result -> key_result and value_result
          end
      end
    else
      :error
    end
  end

  def subtype?({:tuple, list_type1}, {:tuple, list_type2}), do: 
    if length(list_type1) === length(list_type2), do: subtype?(Enum.zip(list_type1, list_type2)), else: :error

  def subtype?({:list, type1}, {:list, type2}), do: subtype?(type1, type2)

  def subtype?(:integer, :float), do: true

  def subtype?(:float, :integer), do: false

  def subtype?(:any, _), do: false

  def subtype?(_, :any), do: true

  def subtype?(:none, _), do: true

  def subtype?(_, :none), do: false

  def subtype?(_, _), do: :error

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