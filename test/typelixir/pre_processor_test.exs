defmodule Typelixir.PreProcessorTest do
  use ExUnit.Case
  alias Typelixir.PreProcessor

  describe "process_file" do
    @test_dir "test/tmp"

    @env %{
      :modules_functions => %{
        "ModuleA.ModuleB" => %{
          {:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]},
          {:test2, 0} => {nil, []},
          {:test3, 1} => {nil, [:integer]},
          {:test3, 2} => {:string, [:integer, :string]}
        },
        "ModuleThree" => %{
          {:test, 2} => {:string, [:integer, :string]}
        }
      },
      :prefix => nil,
      :state => :ok,
      :error_data => %{}
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
        === %{
          error_data: %{}, 
          modules_functions: %{
            "Example" => %{}, 
            "ModuleA.ModuleB" => %{{:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]}, {:test2, 0} => {nil, []}, {:test3, 1} => {nil, [:integer]}, {:test3, 2} => {:string, [:integer, :string]}}, 
            "ModuleThree" => %{{:test, 2} => {:string, [:integer, :string]}}
          }, 
          prefix: nil, 
          state: :ok
        }

      File.write("test/tmp/example.ex", "
        defmodule Example do
          @spec example(integer, boolean) :: float
        end
        defmodule Example2 do
          @spec example(integer, integer) :: boolean
        end
      ")
      assert PreProcessor.process_file("#{@test_dir}/example.ex", @env) 
        === %{
          error_data: %{}, 
          modules_functions: %{
            "Example" => %{{:example, 2} => {:float, [:integer, :boolean]}},
            "Example2" => %{{:example, 2} => {:boolean, [:integer, :integer]}},
            "ModuleA.ModuleB" => %{{:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]}, {:test2, 0} => {nil, []}, {:test3, 1} => {nil, [:integer]}, {:test3, 2} => {:string, [:integer, :string]}}, 
            "ModuleThree" => %{{:test, 2} => {:string, [:integer, :string]}}
          }, 
          prefix: nil, 
          state: :ok
        }

        File.write("test/tmp/example.ex", "
        defmodule Example do
          @spec example(integer, boolean) :: float
          @spec example2() :: integer
          @spec example3(integer) :: nil
          @spec example4([integer], {float, string}, %{any => float}) :: {float, string}
        end
      ")
      assert PreProcessor.process_file("#{@test_dir}/example.ex", @env) 
        === %{
          error_data: %{}, 
          modules_functions: %{
            "Example" => %{{:example, 2} => {:float, [:integer, :boolean]}, {:example2, 0} => {:integer, []}, {:example3, 1} => {nil, [:integer]}, {:example4, 3} => {{:tuple, [:float, :string]}, [list: :integer, tuple: [:float, :string], map: {nil, :float}]}}, 
            "ModuleA.ModuleB" => %{{:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]}, {:test2, 0} => {nil, []}, {:test3, 1} => {nil, [:integer]}, {:test3, 2} => {:string, [:integer, :string]}}, 
            "ModuleThree" => %{{:test, 2} => {:string, [:integer, :string]}}
          }, 
          prefix: nil, 
          state: :ok
        }
    end

    test "returns error when there are repeated function specifications" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          @spec example(integer) :: float
          @spec example(boolean) :: float
        end
      ")
      assert PreProcessor.process_file("#{@test_dir}/example.ex", @env) 
        === %{
          prefix: nil, 
          error_data: %{4 => "example/1 already has a defined type"}, 
          modules_functions: %{
            "ModuleA.ModuleB" => %{{:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]}, {:test2, 0} => {nil, []}, {:test3, 1} => {nil, [:integer]}, {:test3, 2} => {:string, [:integer, :string]}}, 
            "ModuleThree" => %{{:test, 2} => {:string, [:integer, :string]}}, 
            "Example" => %{{:example, 1} => {:float, [:integer]}}
          }, 
          state: :error
      }

      File.write("test/tmp/example.ex", "
        defmodule Example do
          @spec example(integer) :: float
          defmodule Example2 do
            @spec example(integer) :: float
            @spec example2(boolean) :: float
            @spec example2(atom) :: float
          end
        end
      ")
      assert PreProcessor.process_file("#{@test_dir}/example.ex", @env) 
        === %{
          prefix: nil, 
          error_data: %{7 => "example2/1 already has a defined type"}, 
          modules_functions: %{
            "ModuleA.ModuleB" => %{{:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]}, {:test2, 0} => {nil, []}, {:test3, 1} => {nil, [:integer]}, {:test3, 2} => {:string, [:integer, :string]}}, 
            "ModuleThree" => %{{:test, 2} => {:string, [:integer, :string]}}, 
            "Example" => %{{:example, 1} => {:float, [:integer]}},
            "Example.Example2" => %{{:example2, 1} => {:float, [:boolean]}, {:example, 1} => {:float, [:integer]}}
          }, 
          state: :error
      }
    end
  end
end