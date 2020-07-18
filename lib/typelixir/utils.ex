defmodule Typelixir.Utils do
  @moduledoc false

  def prepare_result_data(result) do
    case result[:state] do
      :error ->
        data_merged = Enum.reduce(Map.to_list(result[:error_data]), fn acc, e -> if elem(acc, 0) < elem(e, 0), do: acc, else: e end)
        %{result | data: data_merged}
      :ok -> %{result | data: result[:warnings]}
      _ -> result
    end
  end

  def return_error(elem, env, {line, message}) do
    {elem, %{env | state: :error, error_data: Map.put(env[:error_data], line, message)}}
  end

  def return_merge_vars(elem, env, new_vars) do
    {elem, %{env | vars: Map.merge(env[:vars], new_vars)}}
  end
end