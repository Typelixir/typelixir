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
  def build({{:., _, [{:__aliases__, _, [mod_name]}, fn_name]}, _, _}, env) do
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
end