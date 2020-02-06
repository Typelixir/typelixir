defmodule Typelixir.TypeBuilderTest do
  use ExUnit.Case
  alias Typelixir.TypeBuilder

  describe "build" do
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
      assert TypeBuilder.build([1, "a", :c], @env) === {:list, nil}
      assert TypeBuilder.build([1, 1.2], @env) === {:list, :float}
      assert TypeBuilder.build([1], @env) === {:list, :integer}
      assert TypeBuilder.build([true, false], @env) === {:list, :boolean}
    end

    test "returns tuple type from literals" do
      assert TypeBuilder.build({}, @env) === {:tuple, []}
      assert TypeBuilder.build({1, 2}, @env) === {:tuple, [:integer, :integer]}
      assert TypeBuilder.build({1, 1.2}, @env) === {:tuple, [:integer, :float]}
      assert TypeBuilder.build(
        {"a", :b, [1], {:%{}, [line: 8], [{2, {"a", 1}}, {2.1, {"a", 1}}]}, {:test}}, @env) 
        === {:tuple, [:string, :atom, {:list, :integer}, {:map, {:float, {:tuple, [:string, :integer]}}}, {:tuple, [:atom]}]}
    end

    test "returns map type from literals" do
      assert TypeBuilder.build({:%{}, [line: 8], []}, @env) === {:map, {nil, nil}}
      assert TypeBuilder.build({:%{}, [line: 8], [{1, 2}]}, @env) === {:map, {:integer, :integer}}
      assert TypeBuilder.build({:%{}, [line: 8], [{1, 2.1}]}, @env) === {:map, {:integer, :float}}
      assert TypeBuilder.build({:%{}, [line: 8], [{1, 2.1}, {2.1, 1}]}, @env) === {:map, {:float, :float}}
      assert TypeBuilder.build({:%{}, [line: 8], [{"a", 2.1}, {2.1, 1}]}, @env) === {:map, {nil, :float}}
      assert TypeBuilder.build({:%{}, [line: 8], [{"a", 2.1}, {2.1, true}]}, @env) === {:map, {nil, nil}}
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

    test "returns type from modules functions" do
      assert TypeBuilder.build({{:., [line: 7], [{:__aliases__, [line: 7], [:ModuleOne]}, :test]}, [line: 7], [1]}, @env) === :integer
      assert TypeBuilder.build({{:., [line: 7], [{:__aliases__, [line: 7], [:ModuleOne]}, :test2]}, [line: 7], [1]}, @env) === nil
      assert TypeBuilder.build({{:., [line: 7], [{:__aliases__, [line: 7], [:ModuleTwo]}, :test]}, [line: 7], [1]}, @env) === :string
      assert TypeBuilder.build({{:., [line: 7], [{:__aliases__, [line: 7], [:ModuleThree]}, :test]}, [line: 7], [1]}, @env) === nil
    end
  end
end
  