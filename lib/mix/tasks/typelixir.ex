defmodule Mix.Tasks.Typelixir do
    use Mix.Task
  
    def run(_) do
      prepare()
  
      # could run in parallel
      for file <- get_files() do
        Typelixir.check(file)
      end
    end
  
    defp prepare() do
      Mix.Task.run("compile", [])
    end
  
    defp get_files() do
      project = Mix.Project.config()
      srcs = project[:elixirc_paths]
      all_paths = Mix.Utils.extract_files(srcs, [:ex])
  
      IO.puts "Static Elixir Compiler -> Compiling #{length(all_paths)} #{if (length(all_paths) > 1), do: "files", else: "file"} (.ex)\n"
      all_paths
    end
  end