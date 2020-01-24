defmodule Mix.Tasks.Typelixir do
  use Mix.Task

  def run(_) do
    prepare()
    Typelixir.check(get_paths())
  end

  defp prepare() do
    Mix.Task.run("compile", [])
  end

  defp get_paths() do
    paths = Mix.Project.config()[:elixirc_paths] |> Mix.Utils.extract_files([:ex])

    IO.puts "\nTypelixir -> Compiling #{length(paths)} #{if (length(paths) > 1), do: "files", else: "file"} (.ex)\n"
    paths
  end
  end