defmodule Typelixir.ModuleNamesExtractorTest do
  use ExUnit.Case
  alias Typelixir.ModuleNamesExtractor

  describe "extract_modules_names" do
    @test_dir "test/tmp"

    setup do
      File.mkdir(@test_dir)

      on_exit fn ->
        File.rm_rf @test_dir
      end
    end

    test "returns an empty map when there is no module defined on the file" do
      File.write("test/tmp/example.ex", "")
      assert ModuleNamesExtractor.extract_modules_names(["#{@test_dir}/example.ex"]) 
        === %{}
    end

    test "returns a map with the module name as key and path as value when there is one module" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
        end
      ")
      assert ModuleNamesExtractor.extract_modules_names(["#{@test_dir}/example.ex"]) 
        === %{"Example" => "test/tmp/example.ex"}
    end

    test "returns a map with the modules name as key and path as value when there is more than one module in the same file" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          defmodule Example3 do
          end
        end
        defmodule Example2 do
          defmodule Example3 do
          end
        end
      ")
      assert ModuleNamesExtractor.extract_modules_names(["#{@test_dir}/example.ex"]) 
        === %{"Example" => "test/tmp/example.ex", "Example.Example3" => "test/tmp/example.ex", "Example2" => "test/tmp/example.ex", "Example2.Example3" => "test/tmp/example.ex"}
    end

    test "returns a map with the modules name as key and path as value when there is more than one module" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
        end
      ")
      File.write("test/tmp/example2.ex", "
        defmodule A.B.Example2 do
        end
      ")
      File.write("test/tmp/example3.ex", "
        defmodule Z.H.Example.Example2 do
          defmodule Exa do
          end
        end
      ")
      assert ModuleNamesExtractor.extract_modules_names(["#{@test_dir}/example.ex", "#{@test_dir}/example2.ex", "#{@test_dir}/example3.ex"]) 
        === %{"Example" => "test/tmp/example.ex", "A.B.Example2" => "test/tmp/example2.ex", "Z.H.Example.Example2" => "test/tmp/example3.ex", "Z.H.Example.Example2.Exa" => "test/tmp/example3.ex"}
    end
  end
end
  