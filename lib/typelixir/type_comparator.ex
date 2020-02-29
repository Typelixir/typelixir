defmodule Typelixir.TypeComparator do
  def less_or_equal?(type1, type2) when type1 === type2, do: true
  
  def less_or_equal?(list_type1, list_type2) when (is_list(list_type1) and is_list(list_type2)) do
    if length(list_type1) === length(list_type2) do
      types = Enum.zip(list_type1, list_type2) |> Enum.map(fn {type1, type2} -> less_or_equal?(type1, type2) end)
      if Enum.member?(types, :error), do: :error, else: not Enum.member?(types, false)
    else
      :error
    end
  end

  def less_or_equal?({:map, {key_type1, value_type1}}, {:map, {key_type2, value_type2}}), 
    do: less_or_equal?(key_type1, key_type2) and less_or_equal?(value_type1, value_type2)

  def less_or_equal?({:tuple, list_type1}, {:tuple, list_type2}), do: less_or_equal?(list_type1, list_type2)

  def less_or_equal?({:list, type1}, {:list, type2}), do: less_or_equal?(type1, type2)

  def less_or_equal?(:integer, :float), do: true

  def less_or_equal?(:float, :integer), do: false

  def less_or_equal?(nil, _), do: true

  def less_or_equal?(_, nil), do: false

  def less_or_equal?(_, _), do: :error

  # ---------------------------------------------------------------------------------------------------

  def greater(type1, type2) when type1 === type2, do: type1

  def greater(list_type1, list_type2) when (is_list(list_type1) and is_list(list_type2)) do
    if (length(list_type1) === length(list_type2)), 
      do: Enum.zip(list_type1, list_type2)
          |> Enum.map(fn {type1, type2} -> greater(type1, type2) end),
      else: :error
  end

  def greater({:map, {key_type1, value_type1}}, {:map, {key_type2, value_type2}}), 
    do: {:map, {greater(key_type1, key_type2), greater(value_type1, value_type2)}}

  def greater({:tuple, list_type1}, {:tuple, list_type2}), do: {:tuple, greater(list_type1, list_type2)}

  def greater({:list, type1}, {:list, type2}), do: {:list, greater(type1, type2)}

  def greater(:integer, :float), do: :float
  
  def greater(:float, :integer), do: :float

  def greater(nil, type), do: type

  def greater(type, nil), do: type

  def greater(:error, _), do: :error

  def greater(_, :error), do: :error

  def greater(_, _), do: :error

  # ---------------------------------------------------------------------------------------------------

  def has_type?(list_type, type) when is_list(list_type) do
    Enum.map(list_type, fn t -> has_type?(t, type) end) |> Enum.member?(true)
  end

  def has_type?({:map, {key_type, value_type}}, type), 
    do: has_type?(key_type, type) or has_type?(value_type, type)

  def has_type?({:tuple, list_type}, type), do: has_type?(list_type, type)

  def has_type?({:list, list_type}, type), do: has_type?(list_type, type)

  def has_type?(type1, type2) when type1 === type2, do: true

  def has_type?(_, _), do: false

  # ---------------------------------------------------------------------------------------------------
  
  def int_to_float?(list_type1, list_type2) when (is_list(list_type1) and is_list(list_type2)) do
    if (length(list_type1) === length(list_type2)), 
      do: (Enum.zip(list_type1, list_type2)
          |> Enum.map(fn {type1, type2} -> int_to_float?(type1, type2) end)
          |> Enum.member?(true)),
      else: false
  end

  def int_to_float?({:map, {key_type1, value_type1}}, {:map, {key_type2, value_type2}}), 
    do: int_to_float?(key_type1, key_type2) or int_to_float?(value_type1, value_type2)

  def int_to_float?({:tuple, list_type1}, {:tuple, list_type2}), do: int_to_float?(list_type1, list_type2)

  def int_to_float?({:list, type1}, {:list, type2}), do: int_to_float?(type1, type2)

  def int_to_float?(:integer, :float), do: true

  def int_to_float?(_, _), do: false
end