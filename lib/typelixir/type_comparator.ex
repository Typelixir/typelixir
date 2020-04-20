defmodule Typelixir.TypeComparator do
  # ---------------------------------------------------------------------------------------------------
  # less_or_equal? -> returns true if type1 is less or equal than type2

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
  # greater -> returns the greater between type1 and type2

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
  # has_type? -> returns true if type1 contains type2

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
  # float_to_int? returns true if pattern1 has type integer and the corresponding pattern2 has type float

  # Literals
  def float_to_int?(op1, op2, _env) when (is_integer(op1) and is_float(op2)), do: true

  # Tuple
  def float_to_int?({:{}, _, op1}, {:{}, _, op2}, env) do
    Enum.map(Enum.zip(op1, op2), 
      fn {op1, op2} -> float_to_int?(op1, op2, env) end) 
        |> Enum.member?(true)
  end

  # Map
  def float_to_int?({:%{}, _, op1}, {:%{}, _, op2}, env) do
    Enum.map(Enum.zip(op1, op2), 
      fn {op1, op2} -> float_to_int?(op1, op2, env) end) 
        |> Enum.member?(true)
  end

  # Variables
  def float_to_int?({op1, _, _}, {op2, _, _}, env) do
    if (env[:vars][op1] === :integer and env[:vars][op2] === :float), do: true, else: false
  end

  # Variable - literal
  def float_to_int?({op1, _, _}, op2, env) do
    if (env[:vars][op1] === :integer and is_float(op2)), do: true, else: false
  end

  # List
  def float_to_int?(op1, op2, env) when is_list(op1) do
    Enum.map(Enum.zip(op1, op2), 
      fn {op1, op2} -> float_to_int?(op1, op2, env) end) 
        |> Enum.member?(true)
  end

  # Tuple
  def float_to_int?(op1, op2, env) when is_tuple(op1) do
    Enum.map(Enum.zip(Tuple.to_list(op1), Tuple.to_list(op2)), 
      fn {op1, op2} -> float_to_int?(op1, op2, env) end) 
        |> Enum.member?(true)
  end

  def float_to_int?(_, _, _), do: false

  # ---------------------------------------------------------------------------------------------------
  # float_to_int_type? returns true if type1 has type integer and the corresponding type2 is float
  
  def float_to_int_type?(list_type1, list_type2) when (is_list(list_type1) and is_list(list_type2)) do
    if (length(list_type1) === length(list_type2)), 
      do: (Enum.zip(list_type1, list_type2)
          |> Enum.map(fn {type1, type2} -> float_to_int_type?(type1, type2) end)
          |> Enum.member?(true)),
      else: false
  end
  
  def float_to_int_type?({:map, {key_type1, value_type1}}, {:map, {key_type2, value_type2}}), 
    do: float_to_int_type?(key_type1, key_type2) or float_to_int_type?(value_type1, value_type2)

  def float_to_int_type?({:tuple, list_type1}, {:tuple, list_type2}), do: float_to_int_type?(list_type1, list_type2)

  def float_to_int_type?({:list, type1}, {:list, type2}), do: float_to_int_type?(type1, type2)

  def float_to_int_type?(:integer, :float), do: true
  
  def float_to_int_type?(_, _), do: false
end