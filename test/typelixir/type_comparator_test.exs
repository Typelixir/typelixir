defmodule Typelixir.TypeComparatorTest do
  use ExUnit.Case
  alias Typelixir.TypeComparator

  describe "less_or_equal?" do
    test "returns true when types are equal" do
      assert TypeComparator.less_or_equal?(:string, :string) === true
      assert TypeComparator.less_or_equal?(:boolean, :boolean) === true
      assert TypeComparator.less_or_equal?(:integer, :integer) === true
      assert TypeComparator.less_or_equal?(:float, :float) === true
      assert TypeComparator.less_or_equal?(:atom, :atom) === true
    end

    test "returns false when types are not comparable" do
      assert TypeComparator.less_or_equal?(:string, :boolean) === false
      assert TypeComparator.less_or_equal?(:boolean, :integer) === false
      assert TypeComparator.less_or_equal?(:integer, :atom) === false
      assert TypeComparator.less_or_equal?({:tuple, [:integer]}, :float) === false
      assert TypeComparator.less_or_equal?({:list, :string}, {:tuple, [:integer]}) === false
    end

    test "returns true because integer is less than float" do
      assert TypeComparator.less_or_equal?(:integer, :float) === true
      assert TypeComparator.less_or_equal?(:float, :integer) === false
    end

    test "returns true because nil is less than any other" do
      assert TypeComparator.less_or_equal?(nil, :boolean) === true
      assert TypeComparator.less_or_equal?(nil, :integer) === true
      assert TypeComparator.less_or_equal?(nil, {:list, :string}) === true
      assert TypeComparator.less_or_equal?(nil, {:tuple, [:integer]}) === true
    end

    test "returns true when both map1 key and value types are less or equal than map2" do
      assert TypeComparator.less_or_equal?({:map, {nil, nil}}, {:map, {:integer, :string}}) === true
      assert TypeComparator.less_or_equal?({:map, {:integer, :string}}, {:map, {:integer, :string}}) === true
      assert TypeComparator.less_or_equal?({:map, {:integer, :string}}, {:map, {:float, :string}}) === true
      assert TypeComparator.less_or_equal?({:map, {:integer, {:list, :integer}}}, {:map, {:float, {:list, :integer}}}) === true
      assert TypeComparator.less_or_equal?({:map, {:integer, :string}}, {:map, {:float, :atom}}) === false
    end

    test "returns true when all types of tuple1 are less or equal than tuple2" do
      assert TypeComparator.less_or_equal?({:tuple, []}, {:tuple, []}) === true
      assert TypeComparator.less_or_equal?({:tuple, [nil, nil]}, {:tuple, [:integer, :string]}) === true
      assert TypeComparator.less_or_equal?({:tuple, [:integer, :string]}, {:tuple, [:integer, :string]}) === true
      assert TypeComparator.less_or_equal?({:tuple, [:integer, :string]}, {:tuple, [:float, :string]}) === true
      assert TypeComparator.less_or_equal?({:tuple, [:integer, {:list, :integer}, :boolean]}, {:tuple, [:float, {:list, :float}, :boolean]}) === true
      assert TypeComparator.less_or_equal?({:tuple, [:integer, :string]}, {:tuple, [:float, :atom]}) === false
    end

    test "returns true when type of list1 is less or equal than list2" do
      assert TypeComparator.less_or_equal?({:list, nil}, {:list, nil}) === true
      assert TypeComparator.less_or_equal?({:list, :integer}, {:list, :integer}) === true
      assert TypeComparator.less_or_equal?({:list, :integer}, {:list, :float}) === true
      assert TypeComparator.less_or_equal?({:list, {:list, :integer}}, {:list, {:list, :float}}) === true
      assert TypeComparator.less_or_equal?({:list, :integer}, {:list, :atom}) === false
    end

    test "returns true when all the elements of list1 are less or equal than list2" do
      assert TypeComparator.less_or_equal?([], []) === true
      assert TypeComparator.less_or_equal?([nil, nil], [:integer, :string]) === true
      assert TypeComparator.less_or_equal?([:integer, :string], [:integer, :string]) === true
      assert TypeComparator.less_or_equal?([:integer, :string], [:float, :string]) === true
      assert TypeComparator.less_or_equal?([:integer, {:list, :integer}, :boolean], [:float, {:list, :float}, :boolean]) === true
      assert TypeComparator.less_or_equal?([:integer, :string], [:float, :atom]) === false
      assert TypeComparator.less_or_equal?([:float, :string], [:integer, :string]) === false
      assert TypeComparator.less_or_equal?([:float, :string, :integer], [:float, :string]) === false
    end
  end

  describe "greater" do
    test "returns the type when arguments are equal" do
      assert TypeComparator.greater(:string, :string) === :string
      assert TypeComparator.greater(:boolean, :boolean) === :boolean
      assert TypeComparator.greater(:integer, :integer) === :integer
      assert TypeComparator.greater(:float, :float) === :float
      assert TypeComparator.greater(:atom, :atom) === :atom
    end

    test "returns nil when types are not comparable" do
      assert TypeComparator.greater(:string, :boolean) === nil
      assert TypeComparator.greater(:boolean, :integer) === nil
      assert TypeComparator.greater(:integer, :atom) === nil
      assert TypeComparator.greater({:tuple, [:integer]}, :float) === nil
      assert TypeComparator.greater({:list, :string}, {:tuple, [:integer]}) === nil
    end

    test "returns float because is greater than integer" do
      assert TypeComparator.greater(:integer, :float) === :float
      assert TypeComparator.greater(:float, :integer) === :float
    end

    test "returns any type because is greater than nil" do
      assert TypeComparator.greater(nil, :boolean) === :boolean
      assert TypeComparator.greater(:integer, nil) === :integer
      assert TypeComparator.greater(nil, {:list, :string}) === {:list, :string}
      assert TypeComparator.greater({:tuple, [:integer]}, nil) === {:tuple, [:integer]}
    end

    test "returns the greater type between two maps" do
      assert TypeComparator.greater({:map, {nil, nil}}, {:map, {:integer, :string}}) === {:map, {:integer, :string}}
      assert TypeComparator.greater({:map, {:integer, :string}}, {:map, {:integer, :string}}) === {:map, {:integer, :string}}
      assert TypeComparator.greater({:map, {:integer, :string}}, {:map, {:float, :string}}) === {:map, {:float, :string}}
      assert TypeComparator.greater({:map, {:integer, {:list, :integer}}}, {:map, {:float, {:list, :integer}}}) === {:map, {:float, {:list, :integer}}}
      assert TypeComparator.greater({:map, {:integer, :string}}, {:map, {:float, :atom}}) === {:map, {:float, nil}}
    end

    test "returns the greater type between two tuples" do
      assert TypeComparator.greater({:tuple, []}, {:tuple, []}) === {:tuple, []}
      assert TypeComparator.greater({:tuple, [nil, nil]}, {:tuple, [:integer, :string]}) === {:tuple, [:integer, :string]}
      assert TypeComparator.greater({:tuple, [:integer, :string]}, {:tuple, [:integer, :string]}) === {:tuple, [:integer, :string]}
      assert TypeComparator.greater({:tuple, [:integer, :string]}, {:tuple, [:float, :string]}) === {:tuple, [:float, :string]}
      assert TypeComparator.greater({:tuple, [:integer, {:list, :integer}, :boolean]}, {:tuple, [:float, {:list, :float}, :boolean]}) === {:tuple, [:float, {:list, :float}, :boolean]}
      assert TypeComparator.greater({:tuple, [:integer, :string]}, {:tuple, [:float, :atom]}) === {:tuple, [:float, nil]}
    end

    test "returns the greater type between two lists" do
      assert TypeComparator.greater({:list, nil}, {:list, :string}) === {:list, :string}
      assert TypeComparator.greater({:list, :integer}, {:list, :integer}) === {:list, :integer}
      assert TypeComparator.greater({:list, :integer}, {:list, :float}) === {:list, :float}
      assert TypeComparator.greater({:list, {:list, :integer}}, {:list, {:list, :float}}) === {:list, {:list, :float}}
      assert TypeComparator.greater({:list, :integer}, {:list, :atom}) === {:list, nil}
    end

    test "returns a list with the greater types of two lists" do
      assert TypeComparator.greater([], []) === []
      assert TypeComparator.greater([nil, nil], [:integer, :string]) === [:integer, :string]
      assert TypeComparator.greater([:integer, :string], [:integer, :string]) === [:integer, :string]
      assert TypeComparator.greater([:integer, :string], [:float, :string]) === [:float, :string]
      assert TypeComparator.greater([:integer, :string], [:integer, :float]) === [:integer, nil]
      assert TypeComparator.greater([:integer, {:list, :integer}, :boolean], [:float, {:list, :float}, :boolean]) === [:float, {:list, :float}, :boolean]
      assert TypeComparator.greater([:integer, :string], [:float, :atom]) === [:float, nil]
      assert TypeComparator.greater([:float, :string, :integer], [:float, :string]) === nil
    end
  end
end
  