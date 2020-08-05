defmodule Typelixir.Utils do
  @moduledoc false

  defmacro manage_results(results, do: ok_block) do
    quote do
      case Enum.filter(unquote(results), fn {_, status, _} -> status === :error end) do
        [] -> unquote(ok_block)
        errors -> 
          Enum.each(unquote(results), fn state -> print_state(state) end)
          {:error, Enum.map(errors, fn {path, _, error} -> "#{elem(error, 1)} in #{path}:#{elem(error, 0)}" end)}
      end
    end
  end

  def prepare_result_data(result) do
    case result[:state] do
      :error ->
        data_merged = Enum.reduce(Map.to_list(result[:error_data]), fn acc, e -> if elem(acc, 0) < elem(e, 0), do: acc, else: e end)
        %{result | data: data_merged}
      _ -> result
    end
  end

  def return_error(elem, env, {line, message}) do
    {elem, %{env | state: :error, error_data: Map.put(env[:error_data], line, message)}}
  end

  def return_merge_vars(elem, env, new_vars) do
    {elem, %{env | vars: Map.merge(env[:vars], new_vars)}}
  end

  # ---------------------------------------------------------------------------------------------------
  # print_param -> humanize ast to print error on params

  def print_param([]), do: "[]"

  def print_param([value]), do: "[#{print_param(value)}]"

  def print_param({:|, _, [operand1, operand2]}), do: "#{print_param(operand1)} | #{print_param(operand2)}"

  def print_param({:%{}, _, ops}), do: "%{#{Enum.join(Enum.map(ops, fn {key, value} -> "#{print_param(key)} => #{print_param(value)}" end), ", ")}}"

  def print_param({:{}, _, ops}), do: "{#{Enum.join(Enum.map(ops, fn op -> print_param(op) end), ", ")}}"

  def print_param({value, _, _}), do: Atom.to_string(value)

  def print_param(ops) when is_tuple(ops), do: "{#{Enum.join(Enum.map(Tuple.to_list(ops), fn op -> print_param(op) end), ", ")}}"

  def print_param(value), do: value
end