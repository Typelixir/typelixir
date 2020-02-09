defmodule Type do
  defmacro __using__(_options) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro boolean(_) do end

  defmacro string(_) do end

  defmacro integer(_) do end

  defmacro float(_) do end

  defmacro atom(_) do end

  defmacro list(_) do end
  defmacro list(_, _) do end

  defmacro tuple(_) do end
  defmacro tuple(_, _) do end

  defmacro map(_, _) do end
  defmacro map(_, _, _) do end

  defmacro typedfunc(_, _, _) do end
end