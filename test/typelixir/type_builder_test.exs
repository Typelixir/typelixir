defmodule Typelixir.TypeBuilderTest do
  use ExUnit.Case
  alias Typelixir.TypeBuilder

  describe "build" do
    @vars %{
      a: :integer,
      b: :string,
      c: {:tuple, [{:list, :integer}, :string]},
      d: {:list, :integer}
    }

    test "returns basic types from own notation" do
      assert TypeBuilder.build({:string, [line: 7], nil}, @vars) === :string
      assert TypeBuilder.build({:boolean, [line: 7], nil}, @vars) === :boolean
      assert TypeBuilder.build({:integer, [line: 7], nil}, @vars) === :integer
      assert TypeBuilder.build({:float, [line: 7], nil}, @vars) === :float
      assert TypeBuilder.build({:atom, [line: 7], nil}, @vars) === :atom
      assert TypeBuilder.build({:_, [line: 7], nil}, @vars) === nil
    end

    test "returns compound types from own notation" do
      assert TypeBuilder.build({:list, [line: 7], [{:integer, [line: 7], nil}]}, @vars) === {:list, :integer}
      assert TypeBuilder.build(
        {:tuple, [line: 7], [[{:list, [line: 7], [{:integer, [line: 7], nil}]}, {:string, [line: 7], nil}]]}, 
        @vars) === {:tuple, [{:list, :integer}, :string]}
      assert TypeBuilder.build(
        {:map, [line: 35], [{:float, [line: 35], nil}, {:tuple, [line: 35], [[{:string, [line: 35], nil}, {:integer, [line: 35], nil}]]}]}, 
        @vars) === {:map, {:float, {:tuple, [:string, :integer]}}}
    end

    test "returns basic types from literals" do
      assert TypeBuilder.build("string", @vars) === :string
      assert TypeBuilder.build(true, @vars) === :boolean
      assert TypeBuilder.build(1234, @vars) === :integer
      assert TypeBuilder.build(123.45, @vars) === :float
      assert TypeBuilder.build(:test, @vars) === :atom
    end

    test "returns list type from literals" do
      assert TypeBuilder.build([], @vars) === {:list, nil}
      assert TypeBuilder.build([1, "a", :c], @vars) === {:list, nil}
      assert TypeBuilder.build([1, 1.2], @vars) === {:list, :float}
      assert TypeBuilder.build([1], @vars) === {:list, :integer}
      assert TypeBuilder.build([true, false], @vars) === {:list, :boolean}
    end

    test "returns tuple type from literals" do
      assert TypeBuilder.build({}, @vars) === {:tuple, []}
      assert TypeBuilder.build({1, 2}, @vars) === {:tuple, [:integer, :integer]}
      assert TypeBuilder.build({1, 1.2}, @vars) === {:tuple, [:integer, :float]}
      assert TypeBuilder.build(
        {"a", :b, [1], {:%{}, [line: 8], [{2, {"a", 1}}, {2.1, {"a", 1}}]}, {:test}}, @vars) 
        === {:tuple, [:string, :atom, {:list, :integer}, {:map, {:float, {:tuple, [:string, :integer]}}}, {:tuple, [:atom]}]}
    end

    test "returns map type from literals" do
      assert TypeBuilder.build({:%{}, [line: 8], []}, @vars) === {:map, {nil, nil}}
      assert TypeBuilder.build({:%{}, [line: 8], [{1, 2}]}, @vars) === {:map, {:integer, :integer}}
      assert TypeBuilder.build({:%{}, [line: 8], [{1, 2.1}]}, @vars) === {:map, {:integer, :float}}
      assert TypeBuilder.build({:%{}, [line: 8], [{1, 2.1}, {2.1, 1}]}, @vars) === {:map, {:float, :float}}
      assert TypeBuilder.build({:%{}, [line: 8], [{"a", 2.1}, {2.1, 1}]}, @vars) === {:map, {nil, :float}}
      assert TypeBuilder.build({:%{}, [line: 8], [{"a", 2.1}, {2.1, true}]}, @vars) === {:map, {nil, nil}}
      assert TypeBuilder.build({:%{}, [line: 8], [{2, {"a", 1}}, {2.1, {"a", 1}}]}, @vars) 
        === {:map, {:float, {:tuple, [:string, :integer]}}}
    end

    test "returns type from variables" do
      assert TypeBuilder.build({:error, [line: 7], nil}, @vars) === nil
      assert TypeBuilder.build({:a, [line: 7], nil}, @vars) === :integer
      assert TypeBuilder.build({:b, [line: 7], nil}, @vars) === :string
      assert TypeBuilder.build({:c, [line: 7], nil}, @vars) === {:tuple, [{:list, :integer}, :string]}
      assert TypeBuilder.build({:d, [line: 7], nil}, @vars) === {:list, :integer}
    end
  end
end
  