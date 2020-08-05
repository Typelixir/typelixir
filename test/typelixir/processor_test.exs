defmodule Typelixir.ProcessorTest do
  use ExUnit.Case
  alias Typelixir.Processor

  describe "process_file" do
    @test_dir "test/tmp"

    @env %{
      :functions => %{
        "ModuleA.ModuleB" => %{
          {:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]},
          {:test2, 0} => {:any, []}
        },
        "ModuleC" => %{
          {:test, 2} => {:string, [:integer, :string]}
        },
        "Example" => %{}
      },
      :prefix => nil,
      :type => nil,
      :state => :ok,
      :error_data => %{},
      :data => %{},
      :vars => %{}
    }

    setup do
      File.mkdir(@test_dir)

      on_exit fn ->
        File.rm_rf @test_dir
      end
    end

    # NOTE -> we don't care about the type the module returns

    test "returns ok when there is no module or code defined on the file" do
      File.write("test/tmp/example.ex", "")
      assert Processor.process_file("#{@test_dir}/example.ex", @env) 
        === %{
          :functions => %{
            "ModuleA.ModuleB" => %{
              {:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]},
              {:test2, 0} => {:any, []}
            },
            "ModuleC" => %{
              {:test, 2} => {:string, [:integer, :string]}
            },
            "Example" => %{}
          },
          :prefix => nil,
          :type => :atom,
          :state => :ok,
          :error_data => %{},
          :data => %{},
          :vars => %{}
        }

      File.write("test/tmp/example.ex", "
        defmodule Example do
        end
      ")
      assert Processor.process_file("#{@test_dir}/example.ex", @env) 
        === %{
          :functions => %{
            "ModuleA.ModuleB" => %{
              {:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]},
              {:test2, 0} => {:any, []}
            },
            "ModuleC" => %{
              {:test, 2} => {:string, [:integer, :string]}
            },
            "Example" => %{}
          },
          :prefix => "Example",
          :type => {:list, {:tuple, [:atom, :any]}},
          :state => :ok,
          :error_data => %{},
          :data => %{},
          :vars => %{}
        }
    end

    test "extends env functions with the functions of the import and alias modules" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          import ModuleC
          alias ModuleA.ModuleB
          alias ModuleD, as: D
          
          import UnknownModuleA
          alias UnknownModuleB
        end
      ")
      assert Processor.process_file("#{@test_dir}/example.ex", %{@env | functions: Map.put(@env[:functions], "ModuleD", %{{:test, 1} => {:integer, [:integer]}})}) 
        === %{
          :functions => %{
            "ModuleA.ModuleB" => %{
              {:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]},
              {:test2, 0} => {:any, []}
            },
            "ModuleC" => %{
              {:test, 2} => {:string, [:integer, :string]}
            },
            "Example" => %{
              {:test, 2} => {:string, [:integer, :string]}
            },
            "ModuleB" => %{
              {:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]},
              {:test2, 0} => {:any, []}
            },
            "ModuleD" => %{
              {:test, 1} => {:integer, [:integer]}
            },
            "D" => %{
              {:test, 1} => {:integer, [:integer]}
            },
          },
          :prefix => "Example",
          :type => {:list, {:tuple, [:atom, :any]}},
          :state => :ok,
          :error_data => %{},
          :data => %{},
          :vars => %{}
        }
    end

    test "functions def" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          @spec test(integer) :: integer
          def test(x) do
            x + 1
          end

          def test2(x, y) do
            x + y
          end
        end
      ")

      assert Processor.process_file("#{@test_dir}/example.ex", %{@env | functions: Map.put(@env[:functions], "Example", %{{:test, 1} => {:integer, [:integer]}})}) 
        === %{
          :functions => %{
            "ModuleA.ModuleB" => %{
              {:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]},
              {:test2, 0} => {:any, []}
            },
            "ModuleC" => %{
              {:test, 2} => {:string, [:integer, :string]}
            },
            "Example" => %{
              {:test, 1} => {:integer, [:integer]}
            }
          },
          :prefix => "Example",
          :type => {:list, {:tuple, [:atom, :any]}},
          :state => :ok,
          :error_data => %{},
          :data => %{},
          :vars => %{}
        }

      File.write("test/tmp/example.ex", "
        defmodule Example do
          @spec test(string) :: integer
          def test(x) do
            \"pass\"
          end

          defp test(x) do
            10
          end
        end
      ")

      assert Processor.process_file("#{@test_dir}/example.ex", %{@env | functions: Map.put(@env[:functions], "Example", %{{:test, 1} => {:integer, [:string]}})}) 
        === %{
          :functions => %{
            "ModuleA.ModuleB" => %{
              {:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]},
              {:test2, 0} => {:any, []}
            },
            "ModuleC" => %{
              {:test, 2} => {:string, [:integer, :string]}
            },
            "Example" => %{
              {:test, 1} => {:integer, [:string]}
            }
          },
          :prefix => "Example",
          :type => {:list, :any},
          :state => :error,
          :error_data => %{4 => "Body doesn't match function type on test/1 declaration"},
          :data => {4, "Body doesn't match function type on test/1 declaration"},
          :vars => %{x: :string}
        }
      
      File.write("test/tmp/example.ex", "
        defmodule Example do
          @spec test(integer, string) :: integer
          def test([x], y), do: 10
          defp test(x, x), do: 11

          @spec test2({integer, boolean}) :: integer
          def test2([1, 2]), do: 10 
          def test2({1, true, 3}), do: 11
        end
      ")

      assert Processor.process_file("#{@test_dir}/example.ex", %{@env | functions: Map.put(@env[:functions], "Example", %{
        {:test, 2} => {:integer, [:integer, :string]},
        {:test2, 1} => {:integer, [{:tuple, [:integer, :boolean]}]}
      })}) 
        === %{
          :functions => %{
            "ModuleA.ModuleB" => %{
              {:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]},
              {:test2, 0} => {:any, []}
            },
            "ModuleC" => %{
              {:test, 2} => {:string, [:integer, :string]}
            },
            "Example" => %{
              {:test, 2} => {:integer, [:integer, :string]},
              {:test2, 1} => {:integer, [{:tuple, [:integer, :boolean]}]}
            }
          },
          :prefix => "Example",
          :type => {:list, :any},
          :state => :error,
          :error_data => %{
            4 => "[x] does not have integer type", 
            5 => "Variable x is already defined with type integer", 
            8 => "Parameters does not match type specification", 
            9 => "The number of parameters in tuple does not match the number of types"
          },
          :data => {4, "[x] does not have integer type"},
          :vars => %{}
        }
    end

    test "functions call" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          @spec test(string) :: integer
          def test(x) do
            10
          end
        end
      ")
      assert Processor.process_file("#{@test_dir}/example.ex", %{@env | functions: Map.put(@env[:functions], "Example", %{{:test, 1} => {:integer, [:string]}})}) 
        === %{
          :functions => %{
            "ModuleA.ModuleB" => %{
              {:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]},
              {:test2, 0} => {:any, []}
            },
            "ModuleC" => %{
              {:test, 2} => {:string, [:integer, :string]}
            },
            "Example" => %{
              {:test, 1} => {:integer, [:string]}
            }
          },
          :prefix => "Example",
          :type => {:list, {:tuple, [:atom, :any]}},
          :state => :ok,
          :error_data => %{},
          :data => %{},
          :vars => %{x: :string}
        }
    end
  end
end