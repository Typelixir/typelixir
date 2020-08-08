defmodule Typelixir.PatternBuilderTest do
  use ExUnit.Case
  import Typelixir.PatternBuilder

  describe "type" do
    @env %{
      state: :ok,
      type: nil,
      error_data: %{},
      warnings: %{},
      data: %{},
      prefix: :Module,
      vars: %{
        a: :integer,
        b: :string,
      },
      modules_functions: %{}
    }

    test "returns simple types defined on @spec" do
      assert type({:string, nil, nil}, @env) === :string
      assert type({:boolean, nil, nil}, @env) === :boolean
      assert type({:integer, nil, nil}, @env) === :integer
      assert type({:float, nil, nil}, @env) === :float
      assert type({:atom, nil, nil}, @env) === :atom
      assert type({:any, nil, nil}, @env) === :any
      assert type({:none, nil, nil}, @env) === :none
      assert type({:asd, nil, nil}, @env) === :any
    end

    test "returns types of tuples without elements defined with @spec" do
      assert type({:{}, nil, []}, @env) === {:tuple, []}
    end

    test "returns types of one element tuples defined with @spec" do
      assert type({:{}, nil, [{:integer, nil, nil}]}, @env) === {:tuple, [:integer]}
    end

    test "returns types of two elements tuples defined with @spec" do
      assert type({{:string, nil, nil}, {:integer, nil, nil}}, @env) === {:tuple, [:string, :integer]}
    end

    test "returns types of tuples with more than two elements defined with @spec" do
      assert type({:{}, nil, [{:string, nil, nil}, {:integer, nil, nil}, {:float, nil, nil}]}, @env) === {:tuple, [:string, :integer, :float]}
      assert type({:{}, nil, [{:string, nil, nil}, {:integer, nil, nil}, {:float, nil, nil}, {:atom, nil, nil}]}, @env) === {:tuple, [:string, :integer, :float, :atom]}
    end

    test "returns list types defined with @spec" do
      assert type([], @env) === {:list, :any}
      assert type([{:integer, nil, nil}], @env) === {:list, :integer}
      assert type([{:integer, nil, nil}, {:float, nil, nil}], @env) === {:list, :float}
      assert type([{:any, nil, nil}], @env) === {:list, :any}
      assert type([{:integer, nil, nil}, {:string, nil, nil}], @env) === {:list, :error}
    end

    test "returns map types defined with @spec" do
      assert type({:%{}, nil, []}, @env) === {:map, {:any, :any}}
      assert type({:%{}, nil, [{{:integer, nil, nil}, {:float, nil, nil}}]}, @env) === {:map, {:integer, [:float]}}
      assert type({:%{}, nil, [{{:integer, nil, nil}, {:float, nil, nil}}, {{:float, nil, nil}, {:float, nil, nil}}]}, @env) === {:map, {:float, [:float, :float]}}
      assert type({:%{}, nil, [{{:integer, nil, nil}, {:float, nil, nil}}, {{:string, nil, nil}, {:float, nil, nil}}]}, @env) === {:map, {:error, [:float, :float]}}
      assert type({:%{}, nil, [{{:integer, nil, nil}, {:integer, nil, nil}}, {{:integer, nil, nil}, {:float, nil, nil}}]}, @env) === {:map, {:integer, [:integer, :float]}}
      assert type({:%{}, nil, [{{:none, nil, nil}, {:any, nil, nil}}]}, @env) === {:map, {:none, [:any]}}
    end

    test "returns simple types" do
      assert type("hola", @env) === :string
      assert type(true, @env) === :boolean
      assert type(false, @env) === :boolean
      assert type(1, @env) === :integer
      assert type(1.1, @env) === :float
      assert type(:atom, @env) === :atom
    end

    test "returns tuple types" do
      assert type({:{}, nil, []}, @env) === {:tuple, []}
      assert type({:{}, nil, [1]}, @env) === {:tuple, [:integer]}
      assert type({1,2}, @env) === {:tuple, [:integer, :integer]}
      assert type({:{}, nil, [1, 2, 3]}, @env) === {:tuple, [:integer, :integer, :integer]}
    end

    test "returns list types" do
      assert type([], @env) === {:list, :any}
      assert type([1], @env) === {:list, :integer}
      assert type([1, 1.2], @env) === {:list, :float}
      assert type([1 | [1.2]], @env) === {:list, :float}
      assert type([1, "string"], @env) === {:list, :error}
    end

    test "returns map types" do
      assert type({:%{}, nil, []}, @env) === {:map, {:any, :any}}
      assert type({:%{}, nil, [a: 1, b: 1.2]}, @env) === {:map, {:atom, [:integer, :float]}}
      assert type({:%{}, nil, [{1, 1}, {2, 2.1}]}, @env) === {:map, {:integer, [:integer, :float]}}
      assert type({:%{}, nil, [{1, 1.1}, {1, 2}]}, @env) === {:map, {:integer, [:float, :integer]}}
      assert type({:%{}, nil, [{1, 1}, {2.1, 2.1}]}, @env) === {:map, {:float, [:integer, :float]}}
      assert type({:%{}, nil, [{1, 1}, {"string", 2.1}]}, @env) === {:map, {:error, [:integer, :float]}}
    end

    test "returns variable types" do
      assert type({:a, nil, []}, @env) === :integer
      assert type({:b, nil, []}, @env) === :string
      assert type({:k, nil, []}, @env) === :any
      assert type({:{}, nil, [{:a, nil, nil}]}, @env) === {:tuple, [:integer]}
      assert type([{:a, nil, []}], @env) === {:list, :integer}
      assert type({:%{}, nil, [{{:a, nil, []}, {:b, nil, []}}]}, @env) === {:map, {:integer, [:string]}}
    end

    test "returns wild types" do
      assert type({:_, nil, nil}, @env) === :any
      assert type({:{}, nil, [{:_, nil, nil}]}, @env) === {:tuple, [:any]}
      assert type([{:_, nil, nil}], @env) === {:list, :any}
      assert type([1, {:_, nil, nil}], @env) === {:list, :integer}
      assert type({:%{}, nil, [{{:_, nil, nil}, {:_, nil, nil}}]}, @env) === {:map, {:any, [:any]}}
      assert type({:%{}, nil, [{1, 1}, {{:_, nil, nil}, {:_, nil, nil}}]}, @env) === {:map, {:integer, [:integer, :any]}}
    end

    test "returns binding types" do
      assert type({:=, nil, [true, 1]}, @env) === :error
      assert type({:=, nil, [1, 1.2]}, @env) === :float
    end
  end 

  describe "vars" do
    test "does not return variables when param list is empty" do
      assert vars([], []) === %{}
    end
    
    test "does not return variables when param list has only simple values" do
      assert vars([1, 1.2, true, :un_atom, "un string"], [:integer, :float, :boolean, :atom, :string]) === %{}
      assert vars([1], [:float]) === %{}
      assert vars([1], [:any]) === %{}
      assert vars([1], [:string]) === {:error, "Parameters does not match type specification"}
    end

    test "return variables from simple variable patterns" do
      assert vars([{:a, nil, nil}, {:b, nil, nil}, {:c, nil, nil}, {:d, nil, nil}, {:e, nil, nil}], [:integer, :float, :boolean, :atom, :string]) === %{a: :integer, b: :float, c: :boolean, d: :atom, e: :string}
      assert vars([{:a, nil, nil}, {:a, nil, nil}], [:integer, :float]) === {:error, "Variable a is already defined with type integer"}
      assert vars([{:a, nil, nil}], [:any]) === %{} 
    end

    test "returns variables of composed types" do
      assert vars([{:a, nil, nil}], [{:tuple, [:integer]}]) === %{a: {:tuple, [:integer]}}
      assert vars([{:a, nil, nil}], [{:map, {:integer,[:integer]}}]) === %{a: {:map, {:integer,[:integer]}}}
      assert vars([{:a, nil, nil}], [{:list, :integer}]) === %{a: {:list, :integer}}
    end

    test "return variables from wild patterns" do
      assert vars([{:_, nil, nil}], [:integer]) === %{}
    end

    test "return variables from list patterns" do
      assert vars([[]], [{:list, :any}]) === %{}
      assert vars([[1,2,3]], [{:list, :integer}]) === %{}
      assert vars([[{:a, nil, nil}]], [{:list, :integer}]) === %{a: :integer}
      assert vars([[{:a, nil, nil}, {:b, nil, nil}]], [{:list, :integer}]) === %{a: :integer, b: :integer}
      assert vars([[{:a, nil, nil} | [{:b, nil, nil}]]], [{:list, :integer}]) === %{a: :integer, b: :integer}
    end

    test "return variables from map patterns" do
      assert vars([{:%{}, nil, []}], [{:map, {:any,[]}}]) === %{}
      assert vars([{:%{}, nil, [{1, {:a, nil, nil}}, {2, {:b, nil, nil}}]}], [{:map, {:integer, [:integer, :float]}}]) === %{a: :integer, b: :float}
      assert vars([{:%{}, nil, [{1, {:a, nil, nil}}, {2, {:b, nil, nil}}, {3, {:c, nil, nil}}]}], [{:map, {:integer, [:integer, :float]}}]) === %{a: :integer, b: :float}
      assert vars([{:%{}, nil, [{1, {:a, nil, nil}}, {2, {:b, nil, nil}}]}], [{:map, {:integer, [:integer, :float, :integer]}}]) === %{a: :integer, b: :float}
    end
    
    test "return variables from tuple patterns" do
      assert vars([{:{}, nil, []}], [{:tuple, []}]) === %{}
      assert vars([{:{}, nil, [{:a, nil, nil}]}], [{:tuple, [:integer]}]) === %{a: :integer}
      assert vars([{{:a, [line: 6], nil}, {:b, [line: 6], nil}}], [{:tuple, [:integer, :float]}]) === %{a: :integer, b: :float}
      assert vars([{:{}, nil, [{:a, nil, nil}, {:b, nil, nil}]}], [{:tuple, [:integer, :float, :string]}]) === {:error, "The number of parameters in tuple does not match the number of types"}
      assert vars([{:{}, nil, [{:a, nil, nil}, {:b, nil, nil}, {:c, nil, nil}]}], [{:tuple, [:integer, :float]}]) === {:error, "The number of parameters in tuple does not match the number of types"}
    end

    test "returns error when type and the pattern does not match" do
      assert vars([{:{}, nil, []}], [:integer]) === {:error, "Parameters does not match type specification"}
      assert vars([{:{}, nil, []}], [{:map, {:any,[]}}]) === {:error, "Parameters does not match type specification"}
      assert vars([{:{}, nil, []}], [{:list, :integer}]) === {:error, "Parameters does not match type specification"}

      assert vars([[]], [:integer]) === {:error, "Parameters does not match type specification"}
      assert vars([[]], [{:map, {:any,[]}}]) === {:error, "Parameters does not match type specification"}
      assert vars([[]], [{:tuple, []}]) === {:error, "Parameters does not match type specification"}
      
      assert vars([{:%{}, nil, []}], [:integer]) === {:error, "Parameters does not match type specification"}
      assert vars([{:%{}, nil, []}], [{:tuple, []}]) === {:error, "Parameters does not match type specification"}
      assert vars([{:%{}, nil, []}], [{:list, :integer}]) === {:error, "Parameters does not match type specification"}
    end
  end
end