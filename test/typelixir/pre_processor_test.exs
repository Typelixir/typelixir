defmodule Typelixir.PreProcessorTest do
  use ExUnit.Case
  alias Typelixir.PreProcessor

  describe "process_file" do
    @test_dir "test/tmp"

    @env %{
      ModuleOne: %{
        test: {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]},
        test2: {nil, []},
        test3: {nil, [:integer]}
      },
      ModuleThree: %{
        test: {:string, [:integer, :string]}
      }
    }

    setup do
      File.mkdir(@test_dir)

      on_exit fn ->
        File.rm_rf @test_dir
      end
    end

    test "returns empty when there is no module or code defined on the file" do
      File.write("test/tmp/example.ex", "")
      assert PreProcessor.process_file("#{@test_dir}/example.ex", @env) === @env
    end

    test "returns the module name with the functions defined" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
        end
      ")
      assert PreProcessor.process_file("#{@test_dir}/example.ex", @env) 
        === 
          %{ModuleOne: %{test: {{:tuple, [{:list, :integer}, :string]}, 
          [{:list, :integer}, :string]}, test2: {nil, []}, test3: {nil, [:integer]}}, 
          ModuleThree: %{test: {:string, [:integer, :string]}}, Example: %{}}

      File.write("test/tmp/example.ex", "
        defmodule Example do
          @spec example(integer, boolean) :: float
          @spec example2() :: integer
          @spec example3(integer) :: nil
          @spec example4([integer], {float, string}) :: {float, string}
        end
      ")
      assert PreProcessor.process_file("#{@test_dir}/example.ex", @env) 
        === %{
          ModuleOne: %{
            test: {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]},
            test2: {nil, []},
            test3: {nil, [:integer]}
          },
          ModuleThree: %{
            test: {:string, [:integer, :string]}
          },
          Example: %{
            example: {:float, [:integer, :boolean]},
            example2: {:integer, []},
            example3: {nil, [:integer]},
            example4: {{:tuple, [:float, :string]}, [list: :integer, tuple: [:float, :string]]}
          }
        }
    end
  end
end