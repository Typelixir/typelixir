# Typed Elixir

## Introduction

Elixir possess some basic types such as `integer`, `float`, `string`, `boolean` and `atom` which are dynamically type-checked at runtime.

The aim of this library is to introduce a type system in order to perform static typing on expressions of both basic types and structured types. Besides the basic types, our type system manipulates types for `lists`, `tuples`, `maps` and `functions`. We also include the type `any` as the supertype of all terms, and `none` as the empty type.

Below there are some examples on how the library type checks the code (but they are not extensive to all cases, so if in doubt, give it a try!).

## Structured types

Heterogeneous lists are not allowed. The following list generates a type error:

```elixir
[1, "two", :three ]   # wrong
```

Only homogeneous lists are allowed, like the following ones:

```elixir
[1, 2, 3]   # list of integer
[[1, 2], [3, 4], [5, 6]]   # list of integers lists
```

For maps, all keys must have the same type but each value can have its own type:

```elixir
%{:age => 12, name: "John" }   # map with atom keys
%{1 => 12, name: => "John" }   # wrong
```

For tuples, each element has its own type:

```elixir
{12, "John"}   # duple where the first element is an integer and the second a string
```

Last, integer type can be used as float because it is a subtype of it:

```elixir
[1, 1.5, 2]   # list of float
%{1 => "one", 1.5 => "one dot five" }   # map with float keys
```

## Expressions

For boolean expressions like `and`, `or` and `not` boolean types are expected:

```elixir
true and false   # false
true and (0 < 1)   # true
true or 1   # wrong
```

In the case of comparison operators we are more flexible within Elixir's philosophy. We allow any value even from different types to be compared with each other. However, the return type is always boolean. Therefore:

```elixir
("hi" > 5.0) or false   # true
("hi" > 5.0) * 3   # wrong
```

For `case` sentences, the expression must have the same type as the guards, and the return type of all guards must be the same:

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

The behaviour for `if` and `unless` is the same and for the `cond` sentence, a boolean condition is always expected on each guard.

## Function specifications

The library uses the reserved word `@spec` for functions specs.

It doesn't type-check functions defined with `when` conditions, they will be check at runtime as Elixir does.

One of the main objectives in the design of our type system is to be backwards compatible to allow working with legacy code. In order to do so, we allow the existence of `untyped functions`. We can also see them as functions that doesn't have a `@spec` specification.

In the following example we define a function that takes an integer and returns a float:

``` elixir
@spec func1(integer) :: float
def func1(x) do 
  x * 42.0 
end
```

Function `func1` can be correctly applied to an integer:

```elixir
func1(2)   # 84.0
```

But other kind of applications will fail:

```elixir
func1(2.0)   # wrong
func1("2")   # wrong
```

We can also define functions using the `any` type to avoid the type-check:

```elixir
@spec func2(any) :: boolean
def func2(x) do
    x == x
end
```

All types are subtypes of this one, so this function can be called with any value:

```elixir
func2(1)   # true
func2("one")   # true
func2([1, 2, 3])   # true
```

If we want to specify a function with a list of integers as a parameter we write:

```elixir
@spec func3([integer]) :: integer
def func3([]) do
  0
end

def func3([head|tail]) do
  1 + func3(tail)
end
```

This function can be called:

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

So now we can have `func4` calls like the following:

```elixir
func4([])   # 0
func4([1, 2, 3])   # 3
func4(["1", "2", "3"])   # 3
func4([:one, :two, :three])   # 3

func4([1, :two, "three"])   # wrong
```

A map with more key-value pairs can be used instead of a map with less entries. The next function is applicable to maps that have at least one key-value pair, with atom keys and the first value has atom type:

```elixir
@spec func5(%{atom => atom}) :: boolean
def func5(map) do
    map[:key1] == :one
end
```

So this function can be called with:

```elixir
func5(%{:key1=>:three, :key2=>:three, :key3=>"three"})   # false
func5(%{:key1=>:one, :key2=>:two, :key3=>"three"})   # true

func5(%{"1"=>:one, "two"=>:two})   # wrong -> keys are not atoms
func5(%{:key1=>:one, "two"=>:two, 3=>:three})   # wrong -> keys have different types
func5(%{})   # wrong -> has less key-value pairs
```

If we want to specify a function that takes a map with any key type as a param, we can use the `none` type because, as usual, maps are `covariant` on its key and we have to use the lower type. We can also say that the first elem must have the `any` type to admit maps with any value types:

```elixir
@spec func6(%{none => any}) :: boolean
def func6(map) do
    map[:key1] == :one
end
```

Some invocations to this function are:

```elixir
func6(%{"one"=>:one, "two"=>2, "three"=>"three"})   # false
func6(%{"one"=>1, "two"=>2, "three"=>3})   # false
func6(%{:key1=>:one, :key2=>2, :key3=>"three"})   # true
func6(%{:key1=>:one, :key2=>:two, :key3=>:three})   # false

func6(%{1=>:one, :two=>2, "three"=>"three"})   # wrong -> keys have different types
func6(%{})   # wrong -> has less key-value pairs
```

### Return types

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

As we did with parameters, we can specify that the return type is a list of any:

```elixir
@spec func9([any]) :: [any]
def func9(list) do
    [head | tail] = list
    tail
end
```

Some examples of its usage are:

```elixir
func9([1])   # []
func9([1,2])   # [2]
func9([1.1, 2.0])   # [2.0]
func9(["one", "two", "three"])   # ["two", "three"]
func9([:one, :two])   # [:two]
func9([{1,"one"}, {2,"two"}, {3,"three"}])   # [{2,"two"}, {3,"three"}]
func9([%{1 => 3}, %{2 => "4"}, %{3 => :cinco}])   # [%{2 => "4"}, %{3 => :cinco}]
```
In the same way, this behaviour can be obtained for maps and tuples.

### Runtime errors

Expressions with `any` type can be used anywhere so we could have:

```elixir
func3(func9([0,1]))   # 2
func3(func9(['a', 'b']))   # runtime error
```

Statically both functions are correctly type-checked but dynamically the second one will fail.

As we mentioned before, functions without typing specification have the same behaviour. For example, the following expression type-checks correctly:

```elixir
id(8) + 10               # 18
```

But the following will fail at runtime:

```elixir
"hello" <> Main.fact(9)  # runtime error
id(8) and true           # runtime error
```

## Closing thoughts

We strongly believe that there's plenty of room for further research and improvement of the language in this area.

The library is not extensive to all the language, we are missing some important operators such as `|>` or the mentioned `when`.

It's a proof of concept, the scope of this work is just to cover the expectations of a degree project.
