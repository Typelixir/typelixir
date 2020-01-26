defmodule Typelixir.TypeComparator do
  def less_or_equal?(type1, type2) when type1 === type2, do: true
  
  def less_or_equal?(list_type1, list_type2) when (is_list(list_type1) and is_list(list_type2)) do
    if (length(list_type1) === length(list_type2)), 
      do: not (Enum.zip(list_type1, list_type2)
          |> Enum.map(fn {type1, type2} -> less_or_equal?(type1, type2) end)
          |> Enum.member?(false)),
      else: false
  end

  def less_or_equal?({:map, {key_type1, value_type1}}, {:map, {key_type2, value_type2}}), 
    do: less_or_equal?(key_type1, key_type2) and less_or_equal?(value_type1, value_type2)

  def less_or_equal?({:tuple, list_type1}, {:tuple, list_type2}), do: less_or_equal?(list_type1, list_type2)

  def less_or_equal?({:list, type1}, {:list, type2}), do: less_or_equal?(type1, type2)

  def less_or_equal?(:integer, :float), do: true

  def less_or_equal?(nil, _), do: true

  def less_or_equal?(_, _), do: false

  # ---------------------------------------------------------------------------------------------------

  def greater(type1, type2) when type1 === type2, do: type1

  def greater(list_type1, list_type2) when (is_list(list_type1) and is_list(list_type2)) do
    if (length(list_type1) === length(list_type2)), 
      do: Enum.zip(list_type1, list_type2)
          |> Enum.map(fn {type1, type2} -> greater(type1, type2) end),
      else: nil
  end

  def greater({:map, {key_type1, value_type1}}, {:map, {key_type2, value_type2}}), 
    do: {:map, {greater(key_type1, key_type2), greater(value_type1, value_type2)}}

  def greater({:tuple, list_type1}, {:tuple, list_type2}), do: {:tuple, greater(list_type1, list_type2)}

  def greater({:list, type1}, {:list, type2}), do: {:list, greater(type1, type2)}

  def greater(:integer, :float), do: :float
  
  def greater(:float, :integer), do: :float

  def greater(_, _), do: nil
end