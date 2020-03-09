defmodule TypelixirTest do
  # This test is not intended to cover the main functionality, it is only to 
  # test that the functions on the module works well, and do the step 
  # to the processor correctly. The big test cases will be on processor_test.exs

  use ExUnit.Case
  doctest Typelixir

  describe "check" do
    @test_dir "test/tmp"

    setup do
      File.mkdir(@test_dir)

      on_exit fn ->
        File.rm_rf @test_dir
      end
    end

    test "returns :ok when there is no module or code defined on the file" do
      File.write("test/tmp/example.ex", "")
      assert Typelixir.check(["#{@test_dir}/example.ex"]) === :ok

      File.write("test/tmp/example.ex", "
        defmodule Example do
        end
      ")
      assert Typelixir.check(["#{@test_dir}/example.ex"]) === :ok
    end

    test "returns :ok when a file is well compiled" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          a = 1
        end
      ")
      assert Typelixir.check(["#{@test_dir}/example.ex"]) === :ok
    end

    test "returns :ok when the modules are well compiled and imported from others" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          import Example2
        end
      ")
      File.write("test/tmp/example2.ex", "
        defmodule Example2 do
          b = 3
        end
      ")
      File.write("test/tmp/example3.ex", "
        defmodule Example3 do
          import Example2
        end
      ")
      assert Typelixir.check(["#{@test_dir}/example.ex", "#{@test_dir}/example2.ex", "#{@test_dir}/example3.ex"]) === :ok
    end

    test "returns :error when a file is not well compiled by Typelixir" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          @spec test(integer) :: [integer]
          def test(int) do
            [int]
          end
        end
      ")

      File.write("test/tmp/example2.ex", "
        defmodule Example2 do
          import Example
          a = Example.test(true)
        end
      ")
      assert Typelixir.check(["#{@test_dir}/example.ex", "#{@test_dir}/example2.ex"]) 
        === {:error, ["Type error on function call Example.test in test/tmp/example2.ex:4"]}
    end
  end
end
