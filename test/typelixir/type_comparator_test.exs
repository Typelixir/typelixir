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

    test "returns error when types are not comparable" do
      assert TypeComparator.less_or_equal?(:string, :boolean) === :error
      assert TypeComparator.less_or_equal?(:boolean, :integer) === :error
      assert TypeComparator.less_or_equal?(:integer, :atom) === :error
      assert TypeComparator.less_or_equal?({:tuple, [:integer]}, :float) === :error
      assert TypeComparator.less_or_equal?({:list, :string}, {:tuple, [:integer]}) === :error
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
      assert TypeComparator.less_or_equal?({:map, {:float, :string}}, {:map, {:integer, :string}}) === false
      assert TypeComparator.less_or_equal?({:map, {:integer, :string}}, {:map, {:float, :atom}}) === :error
    end

    test "returns true when all types of tuple1 are less or equal than tuple2" do
      assert TypeComparator.less_or_equal?({:tuple, []}, {:tuple, []}) === true
      assert TypeComparator.less_or_equal?({:tuple, [nil, nil]}, {:tuple, [:integer, :string]}) === true
      assert TypeComparator.less_or_equal?({:tuple, [:integer, :string]}, {:tuple, [:integer, :string]}) === true
      assert TypeComparator.less_or_equal?({:tuple, [:integer, :string]}, {:tuple, [:float, :string]}) === true
      assert TypeComparator.less_or_equal?({:tuple, [:integer, {:list, :integer}, :boolean]}, {:tuple, [:float, {:list, :float}, :boolean]}) === true
      assert TypeComparator.less_or_equal?({:tuple, [:float, :string]}, {:tuple, [:integer, :string]}) === false
      assert TypeComparator.less_or_equal?({:tuple, [:integer, :string]}, {:tuple, [:float, :atom]}) === :error
    end

    test "returns true when type of list1 is less or equal than list2" do
      assert TypeComparator.less_or_equal?({:list, nil}, {:list, nil}) === true
      assert TypeComparator.less_or_equal?({:list, :integer}, {:list, :integer}) === true
      assert TypeComparator.less_or_equal?({:list, :integer}, {:list, :float}) === true
      assert TypeComparator.less_or_equal?({:list, {:list, :integer}}, {:list, {:list, :float}}) === true
      assert TypeComparator.less_or_equal?({:list, :float}, {:list, :integer}) === false
      assert TypeComparator.less_or_equal?({:list, :integer}, {:list, :atom}) === :error
    end

    test "returns true when all the elements of list1 are less or equal than list2" do
      assert TypeComparator.less_or_equal?([], []) === true
      assert TypeComparator.less_or_equal?([nil, nil], [:integer, :string]) === true
      assert TypeComparator.less_or_equal?([:integer, :string], [:integer, :string]) === true
      assert TypeComparator.less_or_equal?([:integer, :string], [:float, :string]) === true
      assert TypeComparator.less_or_equal?([:integer, {:list, :integer}, :boolean], [:float, {:list, :float}, :boolean]) === true
      assert TypeComparator.less_or_equal?([:integer, :string], [:float, :atom]) === :error
      assert TypeComparator.less_or_equal?([:float, :string], [:integer, :string]) === false
      assert TypeComparator.less_or_equal?([:float, :string, :integer], [:float, :string]) === :error
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

    test "returns error when types are not comparable" do
      assert TypeComparator.greater(:string, :boolean) === :error
      assert TypeComparator.greater(:boolean, :integer) === :error
      assert TypeComparator.greater(:integer, :atom) === :error
      assert TypeComparator.greater({:tuple, [:integer]}, :float) === :error
      assert TypeComparator.greater({:list, :string}, {:tuple, [:integer]}) === :error
    end

    test "returns error when one of the type is already an error" do
      assert TypeComparator.greater(:error, :boolean) === :error
      assert TypeComparator.greater(:error, nil) === :error
      assert TypeComparator.greater(nil, :error) === :error
      assert TypeComparator.greater({:tuple, [:integer]}, :error) === :error
      assert TypeComparator.greater({:tuple, [:integer]}, {:map, {:float, :error}}) === :error
      assert TypeComparator.greater({:tuple, [:integer, :error]}, {:map, {:float, :string}}) === :error
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
      assert TypeComparator.greater({:map, {:integer, :string}}, {:map, {:float, :atom}}) === {:map, {:float, :error}}
    end

    test "returns the greater type between two tuples" do
      assert TypeComparator.greater({:tuple, []}, {:tuple, []}) === {:tuple, []}
      assert TypeComparator.greater({:tuple, [nil, nil]}, {:tuple, [:integer, :string]}) === {:tuple, [:integer, :string]}
      assert TypeComparator.greater({:tuple, [:integer, :string]}, {:tuple, [:integer, :string]}) === {:tuple, [:integer, :string]}
      assert TypeComparator.greater({:tuple, [:integer, :string]}, {:tuple, [:float, :string]}) === {:tuple, [:float, :string]}
      assert TypeComparator.greater({:tuple, [:integer, {:list, :integer}, :boolean]}, {:tuple, [:float, {:list, :float}, :boolean]}) === {:tuple, [:float, {:list, :float}, :boolean]}
      assert TypeComparator.greater({:tuple, [:integer, :string]}, {:tuple, [:float, :atom]}) === {:tuple, [:float, :error]}
    end

    test "returns the greater type between two lists" do
      assert TypeComparator.greater({:list, nil}, {:list, :string}) === {:list, :string}
      assert TypeComparator.greater({:list, :integer}, {:list, :integer}) === {:list, :integer}
      assert TypeComparator.greater({:list, :integer}, {:list, :float}) === {:list, :float}
      assert TypeComparator.greater({:list, {:list, :integer}}, {:list, {:list, :float}}) === {:list, {:list, :float}}
      assert TypeComparator.greater({:list, :integer}, {:list, :atom}) === {:list, :error}
    end

    test "returns a list with the greater types of two lists" do
      assert TypeComparator.greater([], []) === []
      assert TypeComparator.greater([nil, nil], [:integer, :string]) === [:integer, :string]
      assert TypeComparator.greater([:integer, :string], [:integer, :string]) === [:integer, :string]
      assert TypeComparator.greater([:integer, :string], [:float, :string]) === [:float, :string]
      assert TypeComparator.greater([:integer, :string], [:integer, :float]) === [:integer, :error]
      assert TypeComparator.greater([:integer, {:list, :integer}, :boolean], [:float, {:list, :float}, :boolean]) === [:float, {:list, :float}, :boolean]
      assert TypeComparator.greater([:integer, :string], [:float, :atom]) === [:float, :error]
      assert TypeComparator.greater([:float, :string, :integer], [:float, :string]) === :error
    end
  end

  describe "has_type?" do
    test "returns true when argument is equal to type" do
      assert TypeComparator.has_type?(:string, :string) === true
      assert TypeComparator.has_type?(:boolean, :boolean) === true
      assert TypeComparator.has_type?(:integer, :integer) === true
      assert TypeComparator.has_type?(:float, :float) === true
      assert TypeComparator.has_type?(:atom, :atom) === true
      assert TypeComparator.has_type?(nil, nil) === true

      assert TypeComparator.has_type?(:float, nil) === false
      assert TypeComparator.has_type?(:integer, :float) === false
      assert TypeComparator.has_type?(:string, :boolean) === false
    end

    test "returns true when key or value types of map are equal to type" do
      assert TypeComparator.has_type?({:map, {:integer, :string}}, :integer) === true
      assert TypeComparator.has_type?({:map, {:integer, {:list, :integer}}}, :integer) === true
      assert TypeComparator.has_type?({:map, {:integer, nil}}, :integer) === true
      assert TypeComparator.has_type?({:map, {nil, :integer}}, :integer) === true

      assert TypeComparator.has_type?({:map, {nil, nil}}, :float) === false
      assert TypeComparator.has_type?({:map, {:integer, :string}}, :float) === false
      assert TypeComparator.has_type?({:map, {:integer, :integer}}, :boolean) === false
    end

    test "returns true when one of tuple types is equal to type" do
      assert TypeComparator.has_type?({:tuple, [nil, :integer]}, :integer) === true
      assert TypeComparator.has_type?({:tuple, [:integer, :string]}, :integer) === true
      assert TypeComparator.has_type?({:tuple, [:integer, {:list, :integer}, :boolean]}, :integer) === true

      assert TypeComparator.has_type?({:tuple, []}, :float) === false
      assert TypeComparator.has_type?({:tuple, [nil, nil]}, :float) === false
      assert TypeComparator.has_type?({:tuple, [:boolean, :string]}, :integer) === false
    end

    test "returns true when type of list contains type" do
      assert TypeComparator.has_type?({:list, :integer}, :integer) === true
      assert TypeComparator.has_type?({:list, {:list, :integer}}, :integer) === true
      assert TypeComparator.has_type?({:list, {:list, nil}}, nil) === true

      assert TypeComparator.has_type?({:list, nil}, :float) === false
      assert TypeComparator.has_type?({:list, {:list, nil}}, :boolean) === false
    end

    test "returns true when one of the types on a list is equal to type" do
      assert TypeComparator.has_type?([:integer, :string], :integer) === true
      assert TypeComparator.has_type?([:integer, {:list, :float}, :boolean], :float) === true
      assert TypeComparator.has_type?([:integer, {:list, :float}, nil], nil) === true

      assert TypeComparator.has_type?([], :float) === false
      assert TypeComparator.has_type?([nil], :atom) === false
      assert TypeComparator.has_type?([nil, :string], :atom) === false
      assert TypeComparator.has_type?([:integer, nil, :string], :float) === false
    end
  end

  describe "float_to_int?" do
    @env %{
      vars: %{
        a: :integer,
        b: :float,
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

    test "returns false when literals are integer and float respectively" do
      assert TypeComparator.float_to_int?(1, 2.4, @env) === true
      assert TypeComparator.float_to_int?(34234, 34324.41142, @env) === true
      assert TypeComparator.float_to_int?(23423, 234, @env) === false
      assert TypeComparator.float_to_int?(14.578, 5857.245, @env) === false
    end

    test "returns false when variables are integer and float respectively" do
      assert TypeComparator.float_to_int?({:a, [line: 7], nil}, {:b, [line: 7], nil}, @env) === true
      assert TypeComparator.float_to_int?({:a, [line: 7], nil}, {:a, [line: 7], nil}, @env) === false
      assert TypeComparator.float_to_int?({:b, [line: 7], nil}, {:b, [line: 7], nil}, @env) === false
    end

    test "returns false when types are not comparable" do
      assert TypeComparator.float_to_int?("a", true, @env) === false
      assert TypeComparator.float_to_int?(false, 112, @env) === false
      assert TypeComparator.float_to_int?(134, :a, @env) === false
      assert TypeComparator.float_to_int?(nil, 123, @env) === false
      assert TypeComparator.float_to_int?(false, nil, @env) === false
    end

    test "returns true when at least one type of list1 is integer and the corresponding type in list2 is float" do
      assert TypeComparator.float_to_int?([], [], @env) === false
      assert TypeComparator.float_to_int?([nil, nil], [2, 4], @env) === false
      assert TypeComparator.float_to_int?([123, "a"], [432, "fdgh"], @env) === false
      assert TypeComparator.float_to_int?([235, "c"], [568.422, "dhr"], @env) === true
      assert TypeComparator.float_to_int?([346, [124314, 25425], true], [23593.2345, [143234.245, 345467.112], false], @env) === true
      assert TypeComparator.float_to_int?([14, "sfg"], [1234.4, :cc], @env) === true
      assert TypeComparator.float_to_int?([134, 567], [567567.576, 34543.534], @env) === true
      assert TypeComparator.float_to_int?([23424.324, "Sg"], [234, "skdgj"], @env) === false
      assert TypeComparator.float_to_int?([252.354, "ektiy", 4597], [579.345, "erg", 3496], @env) === false
    end

    test "returns true when at least one type of tuple1 is integer and the corresponding type in tuple2 is float" do
      assert TypeComparator.float_to_int?({}, {}, @env) === false
      assert TypeComparator.float_to_int?({nil, nil}, {1, 2}, @env) === false
      assert TypeComparator.float_to_int?({123, "a"}, {432, "fdgh"}, @env) === false
      assert TypeComparator.float_to_int?({235, "c"}, {568.422, "dhr"}, @env) === true
      assert TypeComparator.float_to_int?({:{}, [line: 7], [346, [124314, 25425], true]}, {:{}, [line: 7], [23593.2345, [143234.245, 345467.112], false]}, @env) === true
      assert TypeComparator.float_to_int?({14, "sfg"}, {1234.4, :cc}, @env) === true
      assert TypeComparator.float_to_int?({134, 567}, {567567.576, 34543.534}, @env) === true
      assert TypeComparator.float_to_int?({23424.324, "Sg"}, {234, "skdgj"}, @env) === false
      assert TypeComparator.float_to_int?({:{}, [line: 7], [252.354, "ektiy", 4597]}, {:{}, [line: 7], [579.345, "erg", 3496]}, @env) === false
    end

    test "returns true when map1 key or value types are integer and the corresponding map2 key or value types are float" do
      assert TypeComparator.float_to_int?({:%{}, [line: 7], []}, {:%{}, [line: 7], []}, @env) === false
      assert TypeComparator.float_to_int?({:%{}, [line: 7], [{nil, nil}]}, {:%{}, [line: 7], [{1, 2}]}, @env) === false
      assert TypeComparator.float_to_int?({:%{}, [line: 7], [{123, "a"}]}, {:%{}, [line: 7], [{432, "fdgh"}]}, @env) === false
      assert TypeComparator.float_to_int?({:%{}, [line: 7], [{235, "c"}]}, {:%{}, [line: 7], [{568.422, "dhr"}]}, @env) === true
      assert TypeComparator.float_to_int?({:%{}, [line: 7], [{346, [124314, 25425]}, {12412, [123]}]}, {:%{}, [line: 7], [{23593.2345, [143234.245, 345467.112]}, {12412, [123]}]}, @env) === true
      assert TypeComparator.float_to_int?({:%{}, [line: 7], [{14, "sfg"}]}, {:%{}, [line: 7], [{1234.4, :cc}]}, @env) === true
      assert TypeComparator.float_to_int?({:%{}, [line: 7], [{"sfg", 14}]}, {:%{}, [line: 7], [{:cc, 1234.4}]}, @env) === true
      assert TypeComparator.float_to_int?({:%{}, [line: 7], [{134, 567}]}, {:%{}, [line: 7], [{567567.576, 34543.534}]}, @env) === true
      assert TypeComparator.float_to_int?({:%{}, [line: 7], [{23424.324, "Sg"}]}, {:%{}, [line: 7], [{234, "skdgj"}]}, @env) === false
      assert TypeComparator.float_to_int?({:%{}, [line: 7], [{252.354, "ektiy"}, {4597, "Asd"}]}, {:%{}, [line: 7], [{579.345, "erg"}, {3496.123, ":sd"}]}, @env) === true
    end
  end

  describe "float_to_int_type?" do
    test "returns false when types are equal" do
      assert TypeComparator.float_to_int_type?(:string, :string) === false
      assert TypeComparator.float_to_int_type?(:boolean, :boolean) === false
      assert TypeComparator.float_to_int_type?(:integer, :integer) === false
      assert TypeComparator.float_to_int_type?(:float, :float) === false
      assert TypeComparator.float_to_int_type?(:atom, :atom) === false
    end

    test "returns false when types are not comparable" do
      assert TypeComparator.float_to_int_type?(:string, :boolean) === false
      assert TypeComparator.float_to_int_type?(:boolean, :integer) === false
      assert TypeComparator.float_to_int_type?(:integer, :atom) === false
      assert TypeComparator.float_to_int_type?({:tuple, [:integer]}, :float) === false
      assert TypeComparator.float_to_int_type?({:list, :string}, {:tuple, [:integer]}) === false
      assert TypeComparator.float_to_int_type?(nil, :integer) === false
      assert TypeComparator.float_to_int_type?(nil, {:list, :string}) === false
    end

    test "returns true because the first type is integer and the second type is float" do
      assert TypeComparator.float_to_int_type?(:integer, :float) === true
      assert TypeComparator.float_to_int_type?(:float, :integer) === false
    end

    test "returns true when map1 key or value types are integer and the corresponding map2 key or value types are float" do
      assert TypeComparator.float_to_int_type?({:map, {nil, nil}}, {:map, {:integer, :string}}) === false
      assert TypeComparator.float_to_int_type?({:map, {:integer, :string}}, {:map, {:integer, :string}}) === false
      assert TypeComparator.float_to_int_type?({:map, {:integer, :string}}, {:map, {:float, :string}}) === true
      assert TypeComparator.float_to_int_type?({:map, {:integer, {:list, :integer}}}, {:map, {:float, {:list, :integer}}}) === true
      assert TypeComparator.float_to_int_type?({:map, {:integer, :string}}, {:map, {:float, :atom}}) === true
    end

    test "returns true when at least one type of tuple1 is integer and the corresponding type in tuple2 is float" do
      assert TypeComparator.float_to_int_type?({:tuple, []}, {:tuple, []}) === false
      assert TypeComparator.float_to_int_type?({:tuple, [nil, nil]}, {:tuple, [:integer, :string]}) === false
      assert TypeComparator.float_to_int_type?({:tuple, [:integer, :string]}, {:tuple, [:integer, :string]}) === false
      assert TypeComparator.float_to_int_type?({:tuple, [:integer, :string]}, {:tuple, [:float, :string]}) === true
      assert TypeComparator.float_to_int_type?({:tuple, [:integer, {:list, :integer}, :boolean]}, {:tuple, [:float, {:list, :float}, :boolean]}) === true
      assert TypeComparator.float_to_int_type?({:tuple, [:integer, :string]}, {:tuple, [:float, :atom]}) === true
    end

    test "returns true when some type of list1 is integer and the corresponding type in list2 is float" do
      assert TypeComparator.float_to_int_type?({:list, nil}, {:list, nil}) === false
      assert TypeComparator.float_to_int_type?({:list, :integer}, {:list, :integer}) === false
      assert TypeComparator.float_to_int_type?({:list, :integer}, {:list, :float}) === true
      assert TypeComparator.float_to_int_type?({:list, {:list, :integer}}, {:list, {:list, :float}}) === true
      assert TypeComparator.float_to_int_type?({:list, :integer}, {:list, :atom}) === false
    end

    test "returns true when at least one type of list1 is integer and the corresponding type in list2 is float" do
      assert TypeComparator.float_to_int_type?([], []) === false
      assert TypeComparator.float_to_int_type?([nil, nil], [:integer, :string]) === false
      assert TypeComparator.float_to_int_type?([:integer, :string], [:integer, :string]) === false
      assert TypeComparator.float_to_int_type?([:integer, :string], [:float, :string]) === true
      assert TypeComparator.float_to_int_type?([:integer, {:list, :integer}, :boolean], [:float, {:list, :float}, :boolean]) === true
      assert TypeComparator.float_to_int_type?([:integer, :string], [:float, :atom]) === true
      assert TypeComparator.float_to_int_type?([:integer, :integer], [:float, :float]) === true
      assert TypeComparator.float_to_int_type?([:float, :string], [:integer, :string]) === false
      assert TypeComparator.float_to_int_type?([:float, :string, :integer], [:float, :string]) === false
    end
  end
end
  