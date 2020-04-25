defmodule Typelixir do
  @moduledoc false

  alias Typelixir.{ModuleNamesExtractor, Processor}

  def check(all_paths) do
    modules_paths = ModuleNamesExtractor.extract_modules_names(all_paths)

    states = compile_files(all_paths, [], modules_paths, Map.new())
    Enum.each(states, fn state -> print_state(state) end)

    case Enum.filter(states, fn {_, status, _} -> status === :error end) do
      [] -> :ok
      errors -> {:error, Enum.map(errors, fn {path, _, error} -> "#{elem(error, 1)} in #{path}:#{elem(error, 0)}" end)}
    end
  end

  defp compile_files(paths, results, modules_paths, modules_functions) do
    [head | tail] = paths
    {path, state, data, modules_functions} = compile_file(head, modules_functions)

    case state do
      :needs_compile -> 
        new_paths = [modules_paths[data]] ++ Enum.filter(paths, fn e -> e !== modules_paths[data] end)
        compile_files(new_paths, results, modules_paths, modules_functions)
      _ -> 
        results = results ++ [{path, state, data}]

        case tail do
          [] -> results
          rem_paths -> compile_files(rem_paths, results, modules_paths, modules_functions)
        end
    end
  end

  defp compile_file(path, modules_functions) do
    env = %{
      state: :ok,
      type: nil,
      error_data: %{},
      warnings: %{},
      data: %{},
      prefix: nil,
      vars: %{},
      modules_functions: modules_functions
    }
    
    result = Processor.process_file(path, env)
    
    # while developing to see the info in the console
    IO.puts "#{path} env:"
    IO.inspect result
    
    {"#{path}", result[:state], result[:data], result[:modules_functions]}
  end

  defp print_state({path, :error, error}) do
    IO.puts "#{IO.ANSI.red()}error:#{IO.ANSI.white()} #{elem(error, 1)} \n\s\s#{path}:#{elem(error, 0)}\n"
  end

  defp print_state(_), do: nil
end
