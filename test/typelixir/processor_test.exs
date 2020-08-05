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
    # NOTE: we don't care about the type the module returns

    test "modules definition" do
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

    test "import and alias" do
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
      # body
      File.write("test/tmp/example.ex", "
        defmodule Example do
          @spec test(string) :: integer
          defp test(x) do
            10
          end

          def test(x) do
            length([])
          end

          def test(x) do
            \"not pass\"
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
          :error_data => %{12 => "Body doesn't match function type on test/1 declaration"},
          :data => {12, "Body doesn't match function type on test/1 declaration"},
          :vars => %{x: :string}
        }
      
      # params
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
            4 => "Parameters does not match type specification", 
            5 => "Variable x is already defined with type integer", 
            8 => "Parameters does not match type specification", 
            9 => "The number of parameters in tuple does not match the number of types"
          },
          :data => {4, "Parameters does not match type specification"},
          :vars => %{}
        }
    end

    test "functions call" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          @spec test(integer) :: string
          def test(x), do: UnknownModule.test(x)
          def test(x), do: ModuleC.test(x, \"a\")
          def test(x), do: ModuleC.test(true, \"a\")
          def test(x), do: ModuleC.test(x, {1, 2})

          def test2(x, y), do: test(1)
          def test2(x, y), do: test(true)
          def test2(x, y), do: test([1, 2])
        end
      ")
      assert Processor.process_file("#{@test_dir}/example.ex", %{@env | functions: Map.put(@env[:functions], "Example", %{{:test, 1} => {:string, [:integer]}})}) 
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
              {:test, 1} => {:string, [:integer]}
            }
          },
          :prefix => "Example",
          :type => {:list, :any},
          :state => :error,
          :error_data => %{
            6 => "Arguments does not match type specification on test/2", 
            7 => "Arguments does not match type specification on test/2", 
            10 => "Arguments does not match type specification on test/1", 
            11 => "Arguments does not match type specification on test/1"
          },
          :data => {6, "Arguments does not match type specification on test/2"},
          :vars => %{}
        }
    end

    test "binding" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          a = 1
          b = UnknownModule.length(2)
          2 = 2
          {y, z} = {[1, 2.4], false}
          [head | tail] = [2, 4.2]
          c = a + 3.2
          x = a
          a = true
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          :type => {:list, {:tuple, [:atom, :any]}},
          :state => :ok,
          :error_data => %{},
          :data => %{},
          :vars => %{a: :boolean, c: :float, x: :integer, z: :boolean, y: {:list, :float},  head: :float, tail: {:list, :float}}
        }
    end

    test "number operators" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          def test() do
            a = 1 + 2
            b = 2 + 3.4
            c = 1 / 2
            d = length([]) + 2
            e = 4 + \"5\"
          end
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          data: {8, "Type error on + operator"}, 
          error_data: %{8 => "Type error on + operator"}, 
          state: :error, 
          type: {:list, :any}, 
          vars: %{c: :float, a: :integer, b: :float, d: :integer}
        }

      # neg
      File.write("test/tmp/example.ex", "
        defmodule Example do
          def test() do
            f = -1
            g = -1.2
            h = -\"3\"
          end
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          data: {6, "Type error on - operator"}, 
          error_data: %{6 => "Type error on - operator"}, 
          state: :error, 
          type: {:list, :any}, 
          vars: %{f: :integer, g: :float}
        }
    end

    test "boolean operators" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          def test() do
            a = true and false
            b = 1 > 2 and is_list([])
            e = 4 and true
          end
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          data: {6, "Type error on and operator"}, 
          error_data: %{6 => "Type error on and operator"}, 
          state: :error, 
          type: {:list, :any}, 
          vars: %{a: :boolean, b: :boolean}
        }

      # not
      File.write("test/tmp/example.ex", "
        defmodule Example do
          def test() do
            f = not true
            g = not is_atom(:b)
            h = not 10
          end
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          data: {6, "Type error on not operator"}, 
          error_data: %{6 => "Type error on not operator"}, 
          state: :error, 
          type: {:list, :any}, 
          vars: %{f: :boolean, g: :boolean}
        }
    end

    test "comparison operators" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          def test() do
            a = 1 > 2
            b = 3 > true
            e = \"a\" === :a
          end
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          data: %{}, 
          error_data: %{}, 
          state: :ok, 
          type: {:list, {:tuple, [:atom, :any]}}, 
          vars: %{a: :boolean, b: :boolean, e: :boolean}
        }
    end

    test "list operators" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          def test() do
            a = [1] ++ [2]
            b = [1] ++ [2.5]
            c = UnknownModule.list(1, 2) -- [2, 5]
            d = 1 -- [2, 5]
          end
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          data: {7, "Type error on -- operator"}, 
          error_data: %{7 => "Type error on -- operator"}, 
          state: :error, 
          type: {:list, :any}, 
          vars: %{a: {:list, :integer}, b: {:list, :float}, c: {:list, :integer}}
        }
    end

    test "string operators" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          def test() do
            a = \"a\" <> \"b\"
            c = UnknownModule.to_string(1) <> \"b\"
            d = \"1\" <> 10
          end
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          data: {6, "Type error on <> operator"}, 
          error_data: %{6 => "Type error on <> operator"}, 
          state: :error, 
          type: {:list, :any}, 
          vars: %{a: :string, c: :string}
        }
    end

    test "if/unless" do
      # branches
      File.write("test/tmp/example.ex", "
        defmodule Example do
          def test() do
            if (true), do: 10
            if (true), do: 10, else: 10
            
            if (false) do
              true
            else
              10
            end
          end
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          data: {7, "Type error on if branches"}, 
          error_data: %{7 => "Type error on if branches"}, 
          state: :error, 
          type: {:list, :any}, 
          vars: %{}
        }
      
      # condition
      File.write("test/tmp/example.ex", "
        defmodule Example do
          def test() do
            unless (14), do: \"fail\"
          end
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          data: {4, "Type error on unless condition"}, 
          error_data: %{4 => "Type error on unless condition"}, 
          state: :error, 
          type: {:list, :any}, 
          vars: %{}
        }
    end

    test "cond" do
      # branches
      File.write("test/tmp/example.ex", "
        defmodule Example do
          def test() do
            cond do
              1 > 2 -> 10
              true -> 14
            end
            
            cond do
              1 > 2 -> 10
              false -> 100
              true -> \"fail\"
            end
          end
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          data: {12, "Type error on cond branches"}, 
          error_data: %{12 => "Type error on cond branches"}, 
          state: :error, 
          type: {:list, :any}, 
          vars: %{}
        }
      
      # condition
      File.write("test/tmp/example.ex", "
        defmodule Example do
          def test() do
            cond do
              1 > 2 -> 40
              1123 -> 14
              true -> 15
            end
          end
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          data: {6, "Type error on cond condition"}, 
          error_data: %{6 => "Type error on cond condition"}, 
          state: :error, 
          type: {:list, :any}, 
          vars: %{}
        }
    end

    test "case" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          def test(x) do
            case x do
              {x, y} -> 10
              true -> 14
              [x, y] -> x + 10
            end
            
            case x do
              {x, y} -> 10
              true -> 14
              [x, y] -> \"fail\"
            end
          end
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          data: {13, "Type error on case branches"}, 
          error_data: %{13 => "Type error on case branches"}, 
          state: :error, 
          type: {:list, :any}, 
          vars: %{}
        }
    end

    test "map application" do
      File.write("test/tmp/example.ex", "
        defmodule Example do
          def test(x) do
            a = %{1 => 2, 3 => 4}
            b = %{a: :value1, b: :value2}

            c = a[1]
            d = b.a
            e = a[2] + 4

            f = a[:key]
          end
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          data: {11, "Expected integer as key instead of atom"}, 
          error_data: %{11 => "Expected integer as key instead of atom"}, 
          state: :error, 
          type: {:list, :any}, 
          vars: %{a: {:map, {:integer, [:integer, :integer]}}, b: {:map, {:atom, [:atom, :atom]}}, e: :integer}
        }

      File.write("test/tmp/example.ex", "
        defmodule Example do
          def test() do
            a = %{1 => 2, 3 => 4}
            b = c[2]
          end
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          data: {5, "Not accessing to a map"}, 
          error_data: %{5 => "Not accessing to a map"}, 
          state: :error, 
          type: {:list, :any}, 
          vars: %{a: {:map, {:integer, [:integer, :integer]}}}
        }
    end

    test "malformed types" do
      # list
      File.write("test/tmp/example.ex", "
        defmodule Example do
          def test(x) do
            a = [1, 2]
            b = [1, length([])]
            c = [1, 40.0]
            d = []
            e = [1, 2, :a]
          end
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          data: {"", "Malformed type list"}, 
          error_data: %{"" => "Malformed type list"}, 
          state: :error, 
          type: {:list, :any}, 
          vars: %{a: {:list, :integer}, b: {:list, :integer}, c: {:list, :float}, d: {:list, :any}}
        }

      # map
      File.write("test/tmp/example.ex", "
        defmodule Example do
          def test(x) do
            a = %{}
            b = %{1 => \"a\"}
            c = %{40 => :value, 47.5 => :o_value, 30 => length{[1]}}
            d = %{1 => 2, \"2\" => 3}
          end
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
            "Example" => %{
            }
          },
          :prefix => "Example",
          data: {7, "Malformed type map"}, 
          error_data: %{7 => "Malformed type map"}, 
          state: :error, 
          type: {:list, :any}, 
          vars: %{a: {:map, {:any, :any}}, b: {:map, {:integer, [:string]}}, c: {:map, {:float, [:atom, :atom, :any]}}}
        }
    end
  end
end