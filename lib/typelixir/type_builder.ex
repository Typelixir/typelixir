defmodule TypeBuilder do
  def build({:list, _, [type]}) do
    {:list, build(type)}
  end

  def build({:tuple, _, [types_list]}) do
    {:tuple, Enum.map(types_list, fn type -> build(type) end)}
  end

  def build({:map, _, [key_type, value_type]}) do
    {:map, {build(key_type), build(value_type)}}
  end

  def build({:_, _, _}) do
    nil
  end

  def build({type, _, _}) when (type in [:string, :boolean, :integer, :float, :atom]) do
    type
  end

  # Literal Map
  def build({:%{}, _, list}) do
    {:map,
      Enum.map(list, fn {key, elem} -> 
        {:ok, _, k_type} = build(key)
        {:ok, _, v_type} = build(elem)
        {k_type, v_type} end)
      |> Enum.reduce(fn {k_acc, v_acc}, {k_e, v_e} -> 
          if k_acc == k_e do
            if v_acc == v_e do
              {k_acc, v_e}
            else
              {k_acc, nil}
            end
          else
            if v_acc == v_e do
              {nil, v_e}
            else
              {nil, nil}
            end
          end
      end)
    }
  end

  # Literal List
  def build(value) when is_list(value) do
    {:list, Enum.map(value, fn t -> build(t) end) |> Enum.reduce(fn acc, e -> if acc == e, do: acc, else: nil end)}
  end

  # Literal Tuple More Than 2 Elems
  def build({:{}, _, list}) do
    {:tuple, Enum.map(list, fn t -> build(t) end)}
  end

  # Literal Tuple 2 Elems
  def build(value) when is_tuple(value) do
    {:tuple, Enum.map(Tuple.to_list(value), fn t -> build(t) end)}
  end

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