defmodule Type do
  defmacro __using__(_options) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro boolean() do end

  defmacro string() do end

  defmacro integer() do end

  defmacro float() do end

  defmacro atom() do end

  defmacro list(_) do end

  defmacro tuple(_) do end

  defmacro map(_, _) do end

  defmacro typedfunc(_, _, _) do end
end