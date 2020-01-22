defmodule Typelixir do
  @moduledoc false

  def check(all_paths) do
    ModuleNamesExtractor.extract_modules_names(all_paths)
  end
end
