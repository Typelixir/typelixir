# Typelixir

The library proposes a type system that makes possible to perform static type-checking on a significant fragment of Elixir. 

An important feature of the type system is that it does not require any syntactic change to the language. Type information is provided by means of function signatures `@spec`.

The approach is inspired by the so-called [gradual typing](https://en.wikipedia.org/wiki/Gradual_typing).

The proposed type system is based on subtyping and is backwards compatible, as it allows the presence of non-typed code fragments. Represented as the `any` type.

The code parts that are not statically type checked because of lack of typing information, will be type checked then at runtime.

[Here](./lib/TYPE_SYSTEM.md) is the proposed type system and how to write the code to be statically type checked.

### Note

The library is not extensive within the language. The scope of this work is to cover the expectations of a degree project for the [Facutlad de Ingeniería - UDELAR](https://www.fing.edu.uy/). 

Special thanks to our tutors Marcos Viera and Alberto Pardo.

## Documentation

Documentation can be found at [https://hexdocs.pm/typelixir](https://hexdocs.pm/typelixir).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `typelixir` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:typelixir, "~> 0.1.0"}
  ]
end
```

After installing the dependency, you need to run:

```bash
mix typelixir
```

## License

typelixir is licensed under the MIT license.

See [LICENSE](./LICENSE) for the full license text.