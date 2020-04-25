defmodule Typelixir.TypeComparatorTest do
  use ExUnit.Case
  alias Typelixir.TypeComparator

  describe "subtype?" do
    test "returns true when types are equal" do
      assert TypeComparator.subtype?(:string, :string) === true
      assert TypeComparator.subtype?(:boolean, :boolean) === true
      assert TypeComparator.subtype?(:integer, :integer) === true
      assert TypeComparator.subtype?(:float, :float) === true
      assert TypeComparator.subtype?(:atom, :atom) === true
    end

    test "returns error when types are not comparable" do
      assert TypeComparator.subtype?(:string, :boolean) === :error
      assert TypeComparator.subtype?(:boolean, :integer) === :error
      assert TypeComparator.subtype?(:integer, :atom) === :error
      assert TypeComparator.subtype?({:tuple, [:integer]}, :float) === :error
      assert TypeComparator.subtype?({:list, :string}, {:tuple, [:integer]}) === :error
    end

    test "returns true because integer is subtype of float" do
      assert TypeComparator.subtype?(:integer, :float) === true
      assert TypeComparator.subtype?(:float, :integer) === false
    end

    test "returns true because none is subtype of any other" do
      assert TypeComparator.subtype?(:none, :boolean) === true
      assert TypeComparator.subtype?(:none, :integer) === true
      assert TypeComparator.subtype?(:none, {:list, :string}) === true
      assert TypeComparator.subtype?(:none, {:tuple, [:integer]}) === true
    end

    test "returns false because any is supertype of any other" do
      assert TypeComparator.subtype?(:any, :boolean) === false
      assert TypeComparator.subtype?(:any, :integer) === false
      assert TypeComparator.subtype?(:any, {:list, :string}) === false
      assert TypeComparator.subtype?(:any, {:tuple, [:integer]}) === false
    end

    test "returns true when map1 key is subtype of map2 key and map1 value types are subtype of map2 value types" do
      assert TypeComparator.subtype?({:map, {:any, [:none]}}, {:map, {:integer, [:string]}}) === true
      assert TypeComparator.subtype?({:map, {:boolean, [:atom]}}, {:map, {:none, [:any]}}) === true
      assert TypeComparator.subtype?({:map, {:integer, [:string]}}, {:map, {:any, [:none]}}) === false
      assert TypeComparator.subtype?({:map, {:none, [:any]}}, {:map, {:boolean, [:atom]}}) === false

      assert TypeComparator.subtype?({:map, {:integer, [:string]}}, {:map, {:integer, [:string]}}) === true
      assert TypeComparator.subtype?({:map, {:integer, [:string]}}, {:map, {:float, [:string]}}) === false
      assert TypeComparator.subtype?({:map, {:float, [:string]}}, {:map, {:integer, [:string]}}) === true
      assert TypeComparator.subtype?({:map, {:integer, [{:list, :integer}, :integer]}}, {:map, {:float, [{:list, :float}, :integer]}}) === false
      assert TypeComparator.subtype?({:map, {:any, [{:list, :integer}, :integer]}}, {:map, {:float, [{:list, :float}, :integer]}}) === true
      assert TypeComparator.subtype?({:map, {:integer, [:string]}}, {:map, {:float, [:atom]}}) === :error
      assert TypeComparator.subtype?({:map, {:float, [:string]}}, {:map, {:integer, [:atom]}}) === :error
    end

    test "returns true when all types of tuple1 are subtypes of all types of tuple2" do
      assert TypeComparator.subtype?({:tuple, []}, {:tuple, []}) === true
      assert TypeComparator.subtype?({:tuple, [:none, :none]}, {:tuple, [:integer, :string]}) === true
      assert TypeComparator.subtype?({:tuple, [:integer, :string]}, {:tuple, [:integer, :string]}) === true
      assert TypeComparator.subtype?({:tuple, [:integer, :string]}, {:tuple, [:float, :string]}) === true
      assert TypeComparator.subtype?({:tuple, [:integer, {:list, :integer}, :boolean]}, {:tuple, [:float, {:list, :float}, :boolean]}) === true
      assert TypeComparator.subtype?({:tuple, [:float, :string]}, {:tuple, [:integer, :string]}) === false
      assert TypeComparator.subtype?({:tuple, [:integer, :string]}, {:tuple, [:float, :atom]}) === :error
    end

    test "returns true when type of list1 is subtype of type of list2" do
      assert TypeComparator.subtype?({:list, :none}, {:list, :none}) === true
      assert TypeComparator.subtype?({:list, :any}, {:list, :any}) === true
      assert TypeComparator.subtype?({:list, :integer}, {:list, :integer}) === true
      assert TypeComparator.subtype?({:list, :integer}, {:list, :float}) === true
      assert TypeComparator.subtype?({:list, {:list, :integer}}, {:list, {:list, :float}}) === true
      assert TypeComparator.subtype?({:list, :float}, {:list, :integer}) === false
      assert TypeComparator.subtype?({:list, :integer}, {:list, :atom}) === :error
    end

    test "returns true when all the types of the lements of list1 are subtypes of all the types of the elements of list2" do
      assert TypeComparator.subtype?([], []) === true
      assert TypeComparator.subtype?([:none, :none], [:integer, :string]) === true
      assert TypeComparator.subtype?([:integer, :string], [:integer, :string]) === true
      assert TypeComparator.subtype?([:integer, :string], [:float, :string]) === true
      assert TypeComparator.subtype?([:integer, {:list, :integer}, :boolean], [:float, {:list, :float}, :boolean]) === true
      assert TypeComparator.subtype?([:integer, :string], [:float, :atom]) === :error
      assert TypeComparator.subtype?([:float, :string], [:integer, :string]) === false
      assert TypeComparator.subtype?([:float, :string, :integer], [:float, :string]) === :error
    end
  end

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

    test "returns a type because is greater than none" do
      assert TypeComparator.supremum(:none, :boolean) === :boolean
      assert TypeComparator.supremum(:integer, :none) === :integer
      assert TypeComparator.supremum(:none, {:list, :string}) === {:list, :string}
      assert TypeComparator.supremum({:tuple, [:integer]}, :none) === {:tuple, [:integer]}
    end

    test "returns any type because is greater than others" do
      assert TypeComparator.supremum(:any, :boolean) === :any
      assert TypeComparator.supremum(:integer, :any) === :any
      assert TypeComparator.supremum(:any, {:list, :string}) === :any
      assert TypeComparator.supremum({:tuple, [:integer]}, :any) === :any
    end

    test "returns the supremum type between two maps" do
      assert TypeComparator.supremum({:map, {:none, :none}}, {:map, {:integer, :string}}) === {:map, {:integer, :string}}
      assert TypeComparator.supremum({:map, {:integer, :string}}, {:map, {:integer, :string}}) === {:map, {:integer, :string}}
      assert TypeComparator.supremum({:map, {:integer, :string}}, {:map, {:float, :string}}) === {:map, {:float, :string}}
      assert TypeComparator.supremum({:map, {:integer, {:list, :integer}}}, {:map, {:float, {:list, :integer}}}) === {:map, {:float, {:list, :integer}}}
      assert TypeComparator.supremum({:map, {:integer, :string}}, {:map, {:float, :atom}}) === {:map, {:float, :error}}
    end

    test "returns the supremum type between two tuples" do
      assert TypeComparator.supremum({:tuple, []}, {:tuple, []}) === {:tuple, []}
      assert TypeComparator.supremum({:tuple, [:none, :none]}, {:tuple, [:integer, :string]}) === {:tuple, [:integer, :string]}
      assert TypeComparator.supremum({:tuple, [:integer, :string]}, {:tuple, [:integer, :string]}) === {:tuple, [:integer, :string]}
      assert TypeComparator.supremum({:tuple, [:integer, :string]}, {:tuple, [:float, :string]}) === {:tuple, [:float, :string]}
      assert TypeComparator.supremum({:tuple, [:integer, {:list, :integer}, :boolean]}, {:tuple, [:float, {:list, :float}, :boolean]}) === {:tuple, [:float, {:list, :float}, :boolean]}
      assert TypeComparator.supremum({:tuple, [:integer, :string]}, {:tuple, [:float, :atom]}) === {:tuple, [:float, :error]}
    end

    test "returns the supremum type between two lists" do
      assert TypeComparator.supremum({:list, :none}, {:list, :string}) === {:list, :string}
      assert TypeComparator.supremum({:list, :integer}, {:list, :integer}) === {:list, :integer}
      assert TypeComparator.supremum({:list, :integer}, {:list, :float}) === {:list, :float}
      assert TypeComparator.supremum({:list, {:list, :integer}}, {:list, {:list, :float}}) === {:list, {:list, :float}}
      assert TypeComparator.supremum({:list, :integer}, {:list, :atom}) === {:list, :error}
    end

    test "returns a list with the supremum types of two lists" do
      assert TypeComparator.supremum([], []) === []
      assert TypeComparator.supremum([:none, :none], [:integer, :string]) === [:integer, :string]
      assert TypeComparator.supremum([:integer, :string], [:integer, :string]) === [:integer, :string]
      assert TypeComparator.supremum([:integer, :string], [:float, :string]) === [:float, :string]
      assert TypeComparator.supremum([:integer, :string], [:integer, :float]) === [:integer, :error]
      assert TypeComparator.supremum([:integer, {:list, :integer}, :boolean], [:float, {:list, :float}, :boolean]) === [:float, {:list, :float}, :boolean]
      assert TypeComparator.supremum([:integer, :string], [:float, :atom]) === [:float, :error]
      assert TypeComparator.supremum([:float, :string, :integer], [:float, :string]) === :error
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
      assert TypeComparator.has_type?({:map, {:integer, :string}}, :integer) === true
      assert TypeComparator.has_type?({:map, {:integer, {:list, :integer}}}, :integer) === true
      assert TypeComparator.has_type?({:map, {:integer, :none}}, :integer) === true
      assert TypeComparator.has_type?({:map, {:none, :integer}}, :integer) === true
      assert TypeComparator.has_type?({:map, {:any, :integer}}, :integer) === true

      assert TypeComparator.has_type?({:map, {:none, :none}}, :float) === false
      assert TypeComparator.has_type?({:map, {:integer, :string}}, :float) === false
      assert TypeComparator.has_type?({:map, {:integer, :integer}}, :boolean) === false
      assert TypeComparator.has_type?({:map, {:any, :boolean}}, :integer) === false
    end

    test "returns true when one of tuple types is equal to type" do
      assert TypeComparator.has_type?({:tuple, [:none, :integer]}, :integer) === true
      assert TypeComparator.has_type?({:tuple, [:integer, :string]}, :integer) === true
      assert TypeComparator.has_type?({:tuple, [:integer, {:list, :integer}, :boolean]}, :integer) === true
      assert TypeComparator.has_type?({:tuple, [:any, :integer]}, :integer) === true

      assert TypeComparator.has_type?({:tuple, []}, :float) === false
      assert TypeComparator.has_type?({:tuple, [:none, :none]}, :float) === false
      assert TypeComparator.has_type?({:tuple, [:boolean, :string]}, :integer) === false
      assert TypeComparator.has_type?({:tuple, [:any, :any]}, :float) === false
    end

    test "returns true when type of list contains type" do
      assert TypeComparator.has_type?({:list, :integer}, :integer) === true
      assert TypeComparator.has_type?({:list, {:list, :integer}}, :integer) === true
      assert TypeComparator.has_type?({:list, {:list, :none}}, :none) === true
      assert TypeComparator.has_type?({:list, {:list, :any}}, :any) === true

      assert TypeComparator.has_type?({:list, :none}, :float) === false
      assert TypeComparator.has_type?({:list, {:list, :none}}, :boolean) === false
      assert TypeComparator.has_type?({:list, :any}, :float) === false
    end

    test "returns true when one of the types on a list is equal to type" do
      assert TypeComparator.has_type?([:integer, :string], :integer) === true
      assert TypeComparator.has_type?([:integer, {:list, :float}, :boolean], :float) === true
      assert TypeComparator.has_type?([:integer, {:list, :float}, :none], :none) === true
      assert TypeComparator.has_type?([:integer, {:list, :float}, :any], :any) === true

      assert TypeComparator.has_type?([], :float) === false
      assert TypeComparator.has_type?([:none], :atom) === false
      assert TypeComparator.has_type?([:none, :string], :atom) === false
      assert TypeComparator.has_type?([:integer, :none, :string], :float) === false
      assert TypeComparator.has_type?([:any], :atom) === false
    end
  end
end
  