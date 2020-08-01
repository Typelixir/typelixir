defmodule Typelixir do
  @moduledoc false
  
  require Typelixir.Utils
  alias Typelixir.{FunctionsExtractor, Processor}

  @env %{
    state: :ok,
    type: nil,
    error_data: %{},
    data: %{},
    prefix: nil,
    vars: %{},
    functions: %{}
  }

  def check(paths) do
    env_functions = pre_compile_files(paths)

    Typelixir.Utils.manage_results(env_functions[:results]) do
      Typelixir.Utils.manage_results(compile_files(paths, env_functions[:functions])) do
        :ok
      end
    end
  end

  defp pre_compile_files(paths) do      
    Enum.reduce(paths, %{results: [], functions: %{}}, fn path, acc -> 
      result = FunctionsExtractor.extract_functions_file(path, %{@env | functions: acc[:functions]})

      %{acc | 
        functions: Map.merge(acc[:functions], result[:functions]), 
        results: acc[:results] ++ [{"#{path}", result[:state], result[:data]}]}
    end)
  end

  defp compile_files(paths, env_functions) do
    Enum.reduce(paths, [], fn path, acc -> 
      result = Processor.process_file(path, %{@env | functions: env_functions})
      
      # while developing to see the info in the console
      IO.puts "#{path} env:"
      IO.inspect result
      
      acc ++ [{"#{path}", result[:state], result[:data]}]
    end)
  end

  defp print_state({path, :error, error}) do
    IO.puts "#{IO.ANSI.red()}error:#{IO.ANSI.white()} #{elem(error, 1)} \n\s\s#{path}:#{elem(error, 0)}\n"
  end

  defp print_state(_), do: nil
end
