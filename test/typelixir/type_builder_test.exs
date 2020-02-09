defmodule Typelixir.TypeBuilderTest do
  use ExUnit.Case
  alias Typelixir.TypeBuilder

  describe "build" do
    @env %{
      vars: %{
        a: :integer,
        b: :string,
        c: {:tuple, [{:list, :integer}, :string]},
        d: {:list, :integer},
        e: :boolean
      },
      mod_name: :ModuleOne,
      mod_funcs: %{
        ModuleOne: %{
          test: {:integer, [:integer]},
          test2: {nil, [:integer]},
        },
        ModuleTwo: %{test: {:string, []}},
        ModuleThree: %{}
      }
    }

    test "returns basic types from own notation" do
      assert TypeBuilder.build({:string, [line: 7], nil}, @env) === :string
      assert TypeBuilder.build({:boolean, [line: 7], nil}, @env) === :boolean
      assert TypeBuilder.build({:integer, [line: 7], nil}, @env) === :integer
      assert TypeBuilder.build({:float, [line: 7], nil}, @env) === :float
      assert TypeBuilder.build({:atom, [line: 7], nil}, @env) === :atom
      assert TypeBuilder.build({:_, [line: 7], nil}, @env) === nil
    end

    test "returns compound types from own notation" do
      assert TypeBuilder.build({:list, [line: 7], [{:integer, [line: 7], nil}]}, @env) === {:list, :integer}
      assert TypeBuilder.build(
        {:tuple, [line: 7], [[{:list, [line: 7], [{:integer, [line: 7], nil}]}, {:string, [line: 7], nil}]]}, 
        @env) === {:tuple, [{:list, :integer}, :string]}
      assert TypeBuilder.build(
        {:map, [line: 35], [{:float, [line: 35], nil}, {:tuple, [line: 35], [[{:string, [line: 35], nil}, {:integer, [line: 35], nil}]]}]}, 
        @env) === {:map, {:float, {:tuple, [:string, :integer]}}}
    end

    test "returns basic types from literals" do
      assert TypeBuilder.build("string", @env) === :string
      assert TypeBuilder.build(true, @env) === :boolean
      assert TypeBuilder.build(1234, @env) === :integer
      assert TypeBuilder.build(123.45, @env) === :float
      assert TypeBuilder.build(:test, @env) === :atom
    end

    test "returns list type from literals" do
      assert TypeBuilder.build([], @env) === {:list, nil}
      assert TypeBuilder.build([1, "a", :c], @env) === {:list, :error}
      assert TypeBuilder.build([1, 1.2], @env) === {:list, :float}
      assert TypeBuilder.build([1], @env) === {:list, :integer}
      assert TypeBuilder.build([true, false], @env) === {:list, :boolean}
    end

    test "returns tuple type from literals" do
      assert TypeBuilder.build({}, @env) === {:tuple, []}
      assert TypeBuilder.build({1, 2}, @env) === {:tuple, [:integer, :integer]}
      assert TypeBuilder.build({1, 1.2}, @env) === {:tuple, [:integer, :float]}
      assert TypeBuilder.build({:{}, [line: 7],
        ["a", :b, [1], {:%{}, [line: 8], [{2, {"a", 1}}, {2.1, {"a", 1}}]}, {:test}]}, @env)
        === {:tuple, [:string, :atom, {:list, :integer}, {:map, {:float, {:tuple, [:string, :integer]}}}, {:tuple, [:atom]}]}
    end

    test "returns map type from literals" do
      assert TypeBuilder.build({:%{}, [line: 8], []}, @env) === {:map, {nil, nil}}
      assert TypeBuilder.build({:%{}, [line: 8], [{1, 2}]}, @env) === {:map, {:integer, :integer}}
      assert TypeBuilder.build({:%{}, [line: 8], [{1, 2.1}]}, @env) === {:map, {:integer, :float}}
      assert TypeBuilder.build({:%{}, [line: 8], [{1, 2.1}, {2.1, 1}]}, @env) === {:map, {:float, :float}}
      assert TypeBuilder.build({:%{}, [line: 8], [{"a", 2.1}, {2.1, 1}]}, @env) === {:map, {:error, :float}}
      assert TypeBuilder.build({:%{}, [line: 8], [{"a", 2.1}, {2.1, true}]}, @env) === {:map, {:error, :error}}
      assert TypeBuilder.build({:%{}, [line: 8], [{2, {"a", 1}}, {2.1, {"a", 1}}]}, @env) 
        === {:map, {:float, {:tuple, [:string, :integer]}}}
    end

    test "returns type from variables" do
      assert TypeBuilder.build({:error, [line: 7], nil}, @env) === nil
      assert TypeBuilder.build({:a, [line: 7], nil}, @env) === :integer
      assert TypeBuilder.build({:b, [line: 7], nil}, @env) === :string
      assert TypeBuilder.build({:c, [line: 7], nil}, @env) === {:tuple, [{:list, :integer}, :string]}
      assert TypeBuilder.build({:d, [line: 7], nil}, @env) === {:list, :integer}
    end

    test "returns type from own functions" do
      assert TypeBuilder.build({:test, [line: 7], nil}, @env) === :integer
      assert TypeBuilder.build({:test2, [line: 7], nil}, @env) === nil
      assert TypeBuilder.build({:error, [line: 7], nil}, @env) === nil
    end

    test "returns type from modules functions" do
      assert TypeBuilder.build({{:., [line: 7], [{:__aliases__, [line: 7], [:ModuleOne]}, :test]}, [line: 7], [1]}, @env) === :integer
      assert TypeBuilder.build({{:., [line: 7], [{:__aliases__, [line: 7], [:ModuleOne]}, :test2]}, [line: 7], [1]}, @env) === nil
      assert TypeBuilder.build({{:., [line: 7], [{:__aliases__, [line: 7], [:ModuleOne, :ModuleTwo]}, :test]}, [line: 7], [1]}, @env) === :string
      assert TypeBuilder.build({{:., [line: 7], [{:__aliases__, [line: 7], [:ModuleOne, :ModuleTwo, :ModuleThree]}, :test]}, [line: 7], [1]}, @env) === nil
    end

    test "returns type from operators" do
      assert TypeBuilder.build({:+, [line: 41], [1, 2]}, @env) === :integer
      assert TypeBuilder.build({:*, [line: 41], [{:a, [line: 41], nil}, 2]}, @env) === :integer
      assert TypeBuilder.build({:-, [line: 41], [2.3, 2]}, @env) === :float
      assert TypeBuilder.build({:/, [line: 41], [2, 2, 2.4]}, @env) === :float
      assert TypeBuilder.build({:+, [line: 41], [{:z, [line: 41], nil}, 2]}, @env) === nil

      assert TypeBuilder.build({:and, [line: 41], [true, true]}, @env) === :boolean
      assert TypeBuilder.build({:or, [line: 41], [{:e, [line: 41], nil}, false]}, @env) === :boolean
      assert TypeBuilder.build({:and, [line: 41], [{:e, [line: 41], nil}, {:z, [line: 41], nil}, 2]}, @env) === nil

      assert TypeBuilder.build({:not, [line: 41], [true]}, @env) === :boolean
      assert TypeBuilder.build({:not, [line: 41], [{:e, [line: 41], nil}]}, @env) === :boolean
      assert TypeBuilder.build({:not, [line: 41], [{:and, [line: 41], [{:e, [line: 41], nil}, true]}]}, @env) === :boolean
      assert TypeBuilder.build({:not, [line: 41], [{:and, [line: 41], [{:z, [line: 41], nil}, true]}]}, @env) === nil
    end
  end

  describe "add_variables" do
    @env %{
      vars: %{
        a: :integer,
        b: :string,
        c: {:tuple, [{:list, :integer}, :string]},
        d: {:list, :integer}
      },
      mod_funcs: %{
        ModuleOne: %{
          test: {:integer, [:integer]},
          test2: {nil, [:integer]},
        },
        ModuleTwo: %{test: {:string, []}},
        ModuleThree: %{}
      }
    }

    test "does not add variables if the type of operand 2 is nil" do
      assert TypeBuilder.add_variables({:z, [line: 7], nil}, nil, {:h, [line: 7], nil}, nil, @env) === @env[:vars]
      assert TypeBuilder.add_variables({:a, [line: 7], nil}, :integer, {:h, [line: 7], nil}, nil, @env) === @env[:vars]
      assert TypeBuilder.add_variables({:c, [line: 7], nil}, {:list, :integer}, {{:., [line: 7], [{:__aliases__, [line: 7], [:ModuleOne]}, :test_fail]}, [line: 7], [1]}, nil, @env) === @env[:vars]
    end

    test "add variable when type of operand1 is nil" do
      assert TypeBuilder.add_variables({:z, [line: 7], nil}, nil, {:a, [line: 7], nil}, :integer, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, z: :integer}

      assert TypeBuilder.add_variables({:y, [line: 7], nil}, nil, true, :boolean, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, y: :boolean}

      assert TypeBuilder.add_variables({:y, [line: 7], nil}, nil, {true, "a"}, {:tuple, [:boolean, :string]}, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, y: {:tuple, [:boolean, :string]}}

      assert TypeBuilder.add_variables({:y, [line: 7], nil}, nil, {:d, [line: 7], nil}, {:list, :integer}, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, y: {:list, :integer}}
    end

    test "add the variables that are inside a list" do
      assert TypeBuilder.add_variables([], {:list, nil}, [], {:list, nil}, @env) === @env[:vars]

      assert TypeBuilder.add_variables([{:z, [line: 7], nil}, 2], {:list, :integer}, [{:a, [line: 7], nil}, 4], {:list, :integer}, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, z: :integer}

      assert TypeBuilder.add_variables([false, {:y, [line: 7], nil}, true], {:list, :boolean}, [true, false, false], {:list, :boolean}, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, y: :boolean}

      assert TypeBuilder.add_variables([{:y, [line: 7], nil}, {false, "ate"}], {:list, {:tuple, [:boolean, :string]}}, [{true, "a"}, {true, "a"}], {:list, {:tuple, [:boolean, :string]}}, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, y: {:tuple, [:boolean, :string]}}

      assert TypeBuilder.add_variables([[{:y, [line: 7], nil}], [1,2]], {:list, {:list, :integer}}, [[{:d, [line: 7], nil}], [{:d, [line: 7], nil}]], {:list, {:list, :integer}}, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, y: {:list, :integer}}

      assert TypeBuilder.add_variables([[{:y, [line: 7], nil}], [{:z, [line: 7], nil}, 2]], {:list, nil}, [[{:d, [line: 7], nil}], [{:d, [line: 7], nil}, 2]], {:list, {:list, :integer}}, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, y: {:list, :integer}, z: {:list, :integer}}
    end

    test "add the variables that are inside a tuple" do
      assert TypeBuilder.add_variables({}, {:tuple, []}, {}, {:tuple, []}, @env) === @env[:vars]

      assert TypeBuilder.add_variables({{:z, [line: 7], nil}, 2}, {:tuple, [nil, :integer]}, {{:a, [line: 7], nil}, 4}, {:tuple, [:integer, :integer]}, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, z: :integer}

      assert TypeBuilder.add_variables({:{}, [line: 7], [false, {:y, [line: 7], nil}, true]}, {:tuple, [:boolean, nil, :boolean]}, {:{}, [line: 7], [true, false, false]}, {:tuple, [:boolean, :boolean, :boolean]}, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, y: :boolean}

      assert TypeBuilder.add_variables({{:y, [line: 7], nil}, {false, "ate"}}, {:tuple, [nil, {:tuple, [:boolean, :string]}]}, {{true, "a"}, {true, "a"}}, {:tuple, [{:tuple, [:boolean, :string]}, {:tuple, [:boolean, :string]}]}, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, y: {:tuple, [:boolean, :string]}}

      assert TypeBuilder.add_variables({[{:y, [line: 7], nil}], [1,2]}, {:tuple, [nil, {:list, :integer}]}, {[{:d, [line: 7], nil}], [{:d, [line: 7], nil}]}, {:tuple, [{:list, :integer}, {:list, :integer}]}, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, y: {:list, :integer}}

      assert TypeBuilder.add_variables({:{}, [line: 7], [[{:y, [line: 7], nil}], [{:z, [line: 7], nil}, 2], [1,2]]}, {:tuple, [nil, nil]}, {:{}, [line: 7], [[{:d, [line: 7], nil}], [{:d, [line: 7], nil}, 2], [1, 2]]}, {:tuple, [{:list, :integer}, {:list, :integer}]}, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, y: {:list, :integer}, z: {:list, :integer}}
    end

    test "add the variables that are inside a map" do
      assert TypeBuilder.add_variables({:%{}, [line: 7], []}, {:map, {nil, nil}}, {:%{}, [line: 7], []}, {:map, {nil, nil}}, @env) === @env[:vars]

      assert TypeBuilder.add_variables({:%{}, [line: 7], [{2, {:z, [line: 7], nil}}]}, {:map, {:integer, nil}}, {:%{}, [line: 7], [{2, {:a, [line: 7], nil}}]}, {:map, {:integer, :integer}}, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, z: :integer}

      assert TypeBuilder.add_variables({:%{}, [line: 7], [{false, {:y, [line: 7], nil}}, {true, false}]}, {:map, {:boolean, :boolean}}, {:%{}, [line: 7], [{false, false}, {true, false}]}, {:map, {:boolean, :boolean}}, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, y: :boolean}

      assert TypeBuilder.add_variables({:%{}, [line: 7], [{{true, "a"}, {:y, [line: 7], nil}}]}, {:map, {{:tuple, [:boolean, :string]}, nil}}, {:%{}, [line: 7], [{{true, "a"}, {false, "b"}}]}, {:map, {{:tuple, [:boolean, :string]}, {:tuple, [:boolean, :string]}}}, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, y: {:tuple, [:boolean, :string]}}

      assert TypeBuilder.add_variables({:%{}, [line: 7], [{1, [{:y, [line: 7], nil}]}, {2, [{:z, [line: 7], nil}]}]}, {:map, {:integer, {:list, nil}}}, {:%{}, [line: 7], [{1, [{:d, [line: 7], nil}]}, {2, [{:d, [line: 7], nil}]}]}, {:map, {:integer, {:list, :integer}}}, @env) ===
        %{a: :integer, b: :string, c: {:tuple, [{:list, :integer}, :string]}, d: {:list, :integer}, y: {:list, :integer}, z: {:list, :integer}}
    end
  end
end
  