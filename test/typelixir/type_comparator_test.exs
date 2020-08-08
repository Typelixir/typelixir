defmodule Typelixir.TypeComparatorTest do
  use ExUnit.Case
  alias Typelixir.TypeComparator

  describe "supremum" do
    test "returns the type when arguments are equal" do
      assert TypeComparator.supremum(:string, :string) === :string
      assert TypeComparator.supremum(:boolean, :boolean) === :boolean
      assert TypeComparator.supremum(:integer, :integer) === :integer
      assert TypeComparator.supremum(:float, :float) === :float
      assert TypeComparator.supremum(:atom, :atom) === :atom
    end

    test "returns error when types are not comparable" do
      assert TypeComparator.supremum(:string, :boolean) === :error
      assert TypeComparator.supremum(:boolean, :integer) === :error
      assert TypeComparator.supremum(:integer, :atom) === :error
      assert TypeComparator.supremum({:tuple, [:integer]}, :float) === :error
      assert TypeComparator.supremum({:list, :string}, {:tuple, [:integer]}) === :error
    end

    test "returns error when one of the type is already an error" do
      assert TypeComparator.supremum(:error, :boolean) === :error
      assert TypeComparator.supremum(:error, :none) === :error
      assert TypeComparator.supremum(:none, :error) === :error
      assert TypeComparator.supremum({:tuple, [:integer]}, :error) === :error
      assert TypeComparator.supremum({:tuple, [:integer]}, {:map, {:float, :error}}) === :error
      assert TypeComparator.supremum({:tuple, [:integer, :error]}, {:map, {:float, :string}}) === :error
    end

    test "returns float because is greater than integer" do
      assert TypeComparator.supremum(:integer, :float) === :float
      assert TypeComparator.supremum(:float, :integer) === :float
    end

    test "returns type because is greater than none" do
      assert TypeComparator.supremum(:none, :boolean) === :boolean
      assert TypeComparator.supremum(:integer, :none) === :integer
      assert TypeComparator.supremum(:none, {:list, :string}) === {:list, :string}
      assert TypeComparator.supremum({:tuple, [:integer]}, :none) === {:tuple, [:integer]}
    end

    # downcast 
    test "returns type because is less than any but downcast is applied" do
      assert TypeComparator.supremum(:any, :boolean) === :boolean
      assert TypeComparator.supremum(:integer, :any) === :integer
      assert TypeComparator.supremum(:any, {:list, :string}) === {:list, :string}
      assert TypeComparator.supremum({:tuple, [:integer]}, :any) === {:tuple, [:integer]}
    end

    test "returns the supremum type between two maps" do
      assert TypeComparator.supremum({:map, {:integer, [:string]}}, {:map, {:integer, [:string]}}) === {:map, {:integer, [:string]}}
      assert TypeComparator.supremum({:map, {:integer, [:string]}}, {:map, {:float, [:string]}}) === {:map, {:float, [:string]}}
      assert TypeComparator.supremum({:map, {:integer, [{:list, :integer}, :boolean]}}, {:map, {:float, [{:list, :integer}, :boolean]}}) === {:map, {:float, [{:list, :integer}, :boolean]}}
      assert TypeComparator.supremum({:map, {:integer, [:string, :float]}}, {:map, {:float, [:string]}}) === {:map, {:float, [:string]}}

      assert TypeComparator.supremum({:map, {:none, [:any, :string]}}, {:map, {:integer, [:string]}}) === {:map, {:integer, [:string]}}

      assert TypeComparator.supremum({:map, {:integer, [:string]}}, {:map, {:float, [:atom]}}) === {:map, {:float, [:error]}}
      assert TypeComparator.supremum({:map, {:integer, [:string]}}, {:map, {:float, [:string, :atom]}}) === :error
    end

    test "returns the supremum type between two tuples" do
      assert TypeComparator.supremum({:tuple, []}, {:tuple, []}) === {:tuple, []}
      assert TypeComparator.supremum({:tuple, [:integer, :string]}, {:tuple, [:integer, :string]}) === {:tuple, [:integer, :string]}
      assert TypeComparator.supremum({:tuple, [:integer, :string]}, {:tuple, [:float, :string]}) === {:tuple, [:float, :string]}
      assert TypeComparator.supremum({:tuple, [:integer, {:list, :integer}, :boolean]}, {:tuple, [:float, {:list, :float}, :boolean]}) === {:tuple, [:float, {:list, :float}, :boolean]}
      
      assert TypeComparator.supremum({:tuple, [:any, :any]}, {:tuple, [:integer, :string]}) === {:tuple, [:integer, :string]}
      
      assert TypeComparator.supremum({:tuple, [:integer, :string]}, {:tuple, [:float, :atom]}) === {:tuple, [:float, :error]}
      assert TypeComparator.supremum({:tuple, [:integer]}, {:tuple, [:float, :atom]}) === :error
    end

    test "returns the supremum type between two lists" do
      assert TypeComparator.supremum({:list, :integer}, {:list, :integer}) === {:list, :integer}
      assert TypeComparator.supremum({:list, :integer}, {:list, :float}) === {:list, :float}
      assert TypeComparator.supremum({:list, {:list, :integer}}, {:list, {:list, :float}}) === {:list, {:list, :float}}

      assert TypeComparator.supremum({:list, :any}, {:list, :string}) === {:list, :string}
      assert TypeComparator.supremum({:list, {:list, :any}}, {:list, {:list, :integer}}) === {:list, {:list, :integer}}

      assert TypeComparator.supremum({:list, :integer}, {:list, :atom}) === {:list, :error}
      assert TypeComparator.supremum({:list, {:list, :integer}}, {:list, {:list, :atom}}) === {:list, {:list, :error}}
    end

    test "returns a list with the supremum types of two lists" do
      assert TypeComparator.supremum([], []) === []
      assert TypeComparator.supremum([:integer, :string], [:integer, :string]) === [:integer, :string]
      assert TypeComparator.supremum([:integer, :string], [:float, :string]) === [:float, :string]
      assert TypeComparator.supremum([:integer, {:list, :integer}, :boolean], [:float, {:list, :float}, :boolean]) === [:float, {:list, :float}, :boolean]

      assert TypeComparator.supremum([:any, :any], [:integer, :string]) === [:integer, :string]

      assert TypeComparator.supremum([:integer, :float], [:string, :integer]) === [:error, :float]
    end

    test "return the supremum in a list" do
      assert TypeComparator.supremum([:integer]) === :integer
      assert TypeComparator.supremum([:integer, :float]) === :float

      assert TypeComparator.supremum([:any, :integer]) === :integer
      assert TypeComparator.supremum([:any, :any]) === :any

      assert TypeComparator.supremum([:atom, :boolean]) === :error
      assert TypeComparator.supremum([:any, :boolean, :atom]) === :error
    end
  end

  describe "has_type?" do
    test "returns true when argument is equal to type" do
      assert TypeComparator.has_type?(:string, :string) === true
      assert TypeComparator.has_type?(:boolean, :boolean) === true
      assert TypeComparator.has_type?(:integer, :integer) === true
      assert TypeComparator.has_type?(:float, :float) === true
      assert TypeComparator.has_type?(:atom, :atom) === true
      assert TypeComparator.has_type?(:none, :none) === true
      assert TypeComparator.has_type?(:any, :any) === true

      assert TypeComparator.has_type?(:float, :none) === false
      assert TypeComparator.has_type?(:integer, :float) === false
      assert TypeComparator.has_type?(:string, :boolean) === false
      assert TypeComparator.has_type?(:any, :float) === false
    end

    test "returns true when key or value types of map are equal to type" do
      assert TypeComparator.has_type?({:map, {:integer, [:string]}}, :integer) === true
      assert TypeComparator.has_type?({:map, {:integer, [{:list, :integer}]}}, :integer) === true
      assert TypeComparator.has_type?({:map, {:integer, [:any]}}, :integer) === true
      assert TypeComparator.has_type?({:map, {:none, [:integer]}}, :integer) === true

      assert TypeComparator.has_type?({:map, {:none, [:any]}}, :float) === false
      assert TypeComparator.has_type?({:map, {:integer, [:string]}}, :float) === false
      assert TypeComparator.has_type?({:map, {:integer, [:integer]}}, :boolean) === false
      assert TypeComparator.has_type?({:map, {:none, [:boolean]}}, :integer) === false
    end

    test "returns true when one of tuple types contains type" do
      assert TypeComparator.has_type?({:tuple, [:any, :integer]}, :integer) === true
      assert TypeComparator.has_type?({:tuple, [:integer, :string]}, :integer) === true
      assert TypeComparator.has_type?({:tuple, [:integer, {:list, :integer}, :boolean]}, :integer) === true
      assert TypeComparator.has_type?({:tuple, [:any, :integer]}, :integer) === true

      assert TypeComparator.has_type?({:tuple, []}, :float) === false
      assert TypeComparator.has_type?({:tuple, [:any, :any]}, :float) === false
      assert TypeComparator.has_type?({:tuple, [:boolean, :string]}, :integer) === false
      assert TypeComparator.has_type?({:tuple, [:any, :any]}, :float) === false
    end

    test "returns true when type of list contains type" do
      assert TypeComparator.has_type?({:list, :integer}, :integer) === true
      assert TypeComparator.has_type?({:list, {:list, :integer}}, :integer) === true
      assert TypeComparator.has_type?({:list, {:list, :any}}, :any) === true
      assert TypeComparator.has_type?({:list, {:list, :any}}, :any) === true

      assert TypeComparator.has_type?({:list, :any}, :float) === false
      assert TypeComparator.has_type?({:list, {:list, :any}}, :boolean) === false
      assert TypeComparator.has_type?({:list, :any}, :float) === false
    end

    test "returns true when one of the types on a list contains type" do
      assert TypeComparator.has_type?([:integer, :string], :integer) === true
      assert TypeComparator.has_type?([:integer, {:list, :float}, :boolean], :float) === true
      assert TypeComparator.has_type?([:integer, {:list, :float}, :none], :none) === true
      assert TypeComparator.has_type?([:integer, {:list, :float}, :any], :any) === true

      assert TypeComparator.has_type?([], :float) === false
      assert TypeComparator.has_type?([:any], :atom) === false
      assert TypeComparator.has_type?([:any, :string], :atom) === false
      assert TypeComparator.has_type?([:integer, :any, :string], :float) === false
      assert TypeComparator.has_type?([:any], :atom) === false
    end
  end
end
  