defmodule Typelixir.ProcessorTest do
  use ExUnit.Case
  alias Typelixir.Processor

  describe "process_file" do
    @test_dir "test/tmp"

    @env %{
      state: :ok,
      data: [],
      module_name: :empty,
      vars: %{},
      modules_functions: %{}
    }

    setup do
      File.mkdir(@test_dir)

      on_exit fn ->
        File.rm_rf @test_dir
      end
    end

    test "returns ok when there is no module or code defined on the file" do
      File.write("test/tmp/example.ex", "")
      assert Processor.process_file("#{@test_dir}/example.ex", @env) 
        === %{data: [], module_name: :empty, modules_functions: %{}, state: :ok, vars: %{}}

      File.write("test/tmp/example.ex", "
        defmodule Example do
        end
      ")
      assert Processor.process_file("#{@test_dir}/example.ex", @env) 
        === %{data: [], module_name: :Example, modules_functions: %{Example: %{}}, state: :ok, vars: %{}}
    end

    # TO DO ALL THE TEST CASES WE WANT
  end
end