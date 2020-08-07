# Typed Elixir

## Introduction

Elixir posseses some basic types, such as `integer`, `float`, `string`, `boolean` and `atom`, which are dynamically checked at runtime.
The aim of this library is to introduce a type system in order to perform static typing on expressions of both basic types and structured types. Besides the basic types, our type system manipulates types for `lists`, `tuples`, `maps` and `functions`. We also include the type `any`, the type of all terms, and `none` (empty type). 

List types are checket, heterogeneous list are not allowed, the following list generates type error:

```elixir
[1, "two", :three ]   # wrong
```

Only homogeneous lists are allowed, like the following ones:

```elixir
[1, 2, 3]   # list of integer
[[1, 2], [3, 4], [5, 6]]   # list of integer's lists
```

For maps, all keys must have the same type but each value could have its own type:

```elixir
%{:age => 12, name: "John" }   # map with atom keys
%{1 => 12, name: => "John" }   # wrong
```

For tuples, each element has its own type as are defined in Elixir:

```elixir
{12, "John"}   # duple where the first element is an integer and the second a string
```

Also, integer type can be used as float type:

```elixir
[1, 1.5, 2]   # list of float
%{1 => "one", 1.5 => "one dot five" }   # map with float keys
```

## Generic expressions

Expresions are also typechecked. For arithmetic expressions are expected `float` or `integer` types. 

The following are all correct expressions: 

```elixir
3.4 + 5.6   # float
4 + 5   # integer
4.0 + 5   # float
```

However, the following generates a type error:
```elixir
3 + "hi"   # wrong
```

For boolean expresions (`and`, `or` and `not`) boolean types are expected:
```elixir
true and false   # false
true and (0 < 1)   # true
true or 1   # wrong
```

In the case of comparison operators we are more flexible, following Elixir's philosophy. We allow any values, even of different types, to be compared with each other. However, the return type is `boolean`.
Therefore:
```elixir
("hi" > 5.0) or false   # true
("hi" > 5.0) * 3   # wrong
```

We cannot deconstruct a list with, for instance, a tuple pattern. Thus, such patterns are wrongly typed:
```elixir
{x, y} = [1, 2]   # wrong 
```

For `case` sentences, the expression in the case has to have the same type as the guards, and the return type of all guards must have the same type:

```elixir

case 1 > 0 do
  true -> 1
  false -> 1.5
end # 1

case 1 + 2 do
  2 -> "This is wrong"
  3 -> "This is right"
end # "This is right"

case 1 + 2 do
  "tres" -> "This is wrong"
  3 -> "This is right"
end # wrong

case 1 + 2 do
  1 -> :wrong
  3 -> "This is right"
end # wrong
```

The behavior for the `if` sentence is the same. For the `cond` sentence, a boolean condition is expected on each guard.

## Function specifications

The library uses the reserved word `@spec` for functions specs. There is no other type annotation introduced. 

One of the main objectives of the design of our type system is to be backward compatible, to allow working with legacy code. To do so we allow the existence of `untyped functions`. An untyped function is a function that does not have an `@spec` specification.

In the following example we define a function that takes an integer and returns a float:

``` elixir
@spec func1(integer) :: float
def func1(x) do 
  x * 42.0 
end
```

Function `func` can be correctly applied to an integer:
```elixir
func1(2)   # 84.0
```

but other kinds of applications would fail:
```elixir
func1(2.0)   # wrong
func1("2")   # wrong
```

We can also define functions using the type `any` to avoid the typecheck:

```elixir
@spec func2(any) :: boolean
def func2(x) do
    x == x
end
```

Every type is subtype of this type so this function can be called with any value:

```elixir
func2(1)   # true
func2("one")   # true
func2([1, 2, 3])   # true
```

If we want to specify a function with a list of integer as parameter we write:

```elixir
@spec func3([integer]) :: integer
def func3([]) do
    0
end
def func3([head|tail]) do
    1 + func3(tail)
end
```

This function can be called with:

```elixir
func3([])   # 0
func3([1, 2, 3])   # 3

func3(["1", "2", "3"])   # wrong
func3([:one, :two, :three])   # wrong
func3([1, :two, "three"])   # wrong
```

Note that the empty list can be used as a list of any type.

Also, we can define a function applicable to all list types using the `any` type:

```elixir
@spec func4([any]) :: integer
def func4([]) do
    0
end

def func4([head|tail]) do
    1 + func4(tail)
end
```

Some calls to this function are:

```elixir
func4([])   # 0
func4([1, 2, 3])   # 3
func4(["1", "2", "3"])   # 3
func4([:one, :two, :three])   # 3

func4([1, :two, "three"])   # wrong
```

A map with more key-value pairs can be used insted of a map with less entries. The next function is applicable to maps that have at least one key-value pair, with atom keys and the first value has atom type:

```elixir
@spec func5(%{atom => atom}) :: boolean
def func5(map) do
    map[:key1] == :one
end
```

So, this function can be called with:

```elixir
func5(%{:key1=>:three, :key2=>:three, :key3=>"three"})   # false
func5(%{:key1=>:one, :key2=>:two, :key3=>"three"})   # true

func5(%{"1"=>:one, "two"=>:two})   # wrong -> keys are not atoms
func5(%{:key1=>:one, "two"=>:two, 3=>:three})   # wrong -> keys have different types
func5(%{})   # wrong -> has less key-value pairs
```

If we want to specify a function that takes a map with any key type as param we can use the `none` type because, as it is usual, maps are covariant on its key and we have to use the lower type. We can also say that the fist elem has to have type `any` to admit maps with any value types.


```elixir
@spec func6(%{none => any}) :: boolean
def func6(map) do
    map[:key1] == :one
end
```

Some invocation to this function are:

```elixir
func6(%{"one"=>:one, "two"=>2, "three"=>"three"})   # false
func6(%{"one"=>1, "two"=>2, "three"=>3})   # false
func6(%{:key1=>:one, :key2=>2, :key3=>"three"})   # true
func6(%{:key1=>:one, :key2=>:two, :key3=>:three})   # false

func6(%{1=>:one, :two=>2, "three"=>"three"})   # wrong -> keys have different types
func5(%{})   # wrong -> has less key-value pairs
```

If we want to define a function that receives a tuple where the first elem could have any type but the second has to be an integer we can define:

```elixir
@spec func7({any, integer}) :: boolean
def func7({x, y}) do
    y > 2
end
```

We can invoke this function as:

```elixir
func7({1, 1})   # false
func7({2, 3})   # true
func7({:two, 3})   # true
func7({"one", 4})   # true

func7({5,"three"})   # wrong
```

If we don't want to specify the return type we can denote it as `any`:

```elixir
@spec func8([any]) :: any
def func8(list) do
    [head | tail] = list
    head
end
```

This function can be called as:

```elixir
func8(["one", "two", "three"])   # "one"
func8([1, 2, 3])   # 1
func8([:one, :two, :three])   # :one
func8([[1,2,3], [4,5,6], [7,8,9]])   # [1,2,3]
```

As we did for parameters, we can specify that the return type is a list of any type:

```elixir
@spec func9([any]) :: [any]
def func9(list) do
    [head | tail] = list
    tail
end
```

Some examples of usage are:

```elixir
func9([1])   # []
func9([1,2])   # [2]
func9([1.1, 2.0])   # [2.0]
func9(["one", "two", "three"])   # ["two", "three"]
func9([:one, :two])   # [:two]
func9([{1,"one"}, {2,"two"}, {3,"three"}])   # [{2,"two"}, {3,"three"}]
func9([%{1 => 3}, %{2 => "4"}, %{3 => :cinco}])   # [%{2 => "4"}, %{3 => :cinco}]
```
In the same way, this behavior can be obtained for maps and tuples. For maps and tuples of one element we can use the types `%{none => any}` and `{any}`.

Is responsability of the developer the definition of this kind of functions. Expressions with `any` type can be used anywhere as any type so, we could have:

```elixir
func3(func9([0,1]))   # 2
func3(func9(['a', 'b']))   # runtime error
```

Statically both functions are correctly typechecked, but dynamically the second one will fail with type error.

As we mentioned before, functions without type specification have the same behaviour. For example, the following expression correctly typechecks:

```elixir
id(8) + 10               # 18
```

However, the following expressions typecheck, but fail at runtime:

```elixir
"hello" <> Main.fact(9)  # runtime error
id(8) and true           # runtime error
```