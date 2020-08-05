# Typed Elixir

Elixir posseses some basic types, such as `Integer`, `Float`, `String`, `Boolean` and `Atom`, which are dynamically checked at runtime.
In this work our aim is to introduce a type system in order to perform static typing on expressions of both basic types and structured types. Besides the basic types, our type system manipulates types for lists, tuples, maps and functions. We also include the type \emph{Any}, the type of all terms, and \emph{None} (empty type). 
Next we describe the main characteristics of our typed version of Elixir fragment. Our type system is based on subtyping; the subtyping relation is written ($<:$). For instance $Integer <: Float$.

Modulo subtyping, the typing of operators is standard.
%e.g. the type of \texttt{+} is $(Float, Float) \rightarrow Float$.
For example, the arithmetic operators restrict its operands to be numeric.
In our type system, this restriction is fulfilled by requiring the operands to be of a subtype of $Float$. Then, the following are all correct expressions: 
%
\begin{lstlisting}
3.4 + 5.6     # float
4 + 5         # integer
4.0 + 5       # float
\end{lstlisting}
%
However, the following generates a type error:
%
\begin{lstlisting}
3 + "hi"     # wrong
\end{lstlisting}

In the case of comparison operators we are more flexible, following Elixir's philosophy. We allow any values, even of different types, to be compared with each other. However, the return type is $Boolean$.
Therefore:
%
\begin{lstlisting}
("hi" > 5.0) or false   # boolean
("hi" > 5.0) * 3        # wrong
\end{lstlisting}

Except for functions, our program codes do not contain any type annotation.
We use the \texttt{@spec} directive to specify the type of a function.
Function types are of the form $(t_1, ..., t_n) \rightarrow t$, where $t_1, ..., t_n$ are the types of the parameters and $t$ is the return type.
In the following example we define a function that takes an integer and returns a float.
%
\begin{lstlisting}
@spec func(integer) :: float
def func(x) do x * 42.0 end
\end{lstlisting}
%
Function \texttt{func} can be correctly applied to an integer:
\begin{lstlisting}
func(2)    # 84.0
\end{lstlisting}
%
but other kinds of applications would fail:
\begin{lstlisting}
func(2.0)   # wrong
func("2")   # wrong
\end{lstlisting}

%The type for lists is $List(t)$; i.e. 
In our type system, we restrict lists to be homogeneous.
The following examples define correctly typed lists:
\begin{lstlisting}
xs = [9   | []]  # List(integer)
ys = [2.0 | xs]  # List(float)
\end{lstlisting}
%
On the other hand, the following is incorrect:
%
\begin{lstlisting}
zs = [true | ys]  # wrong
\end{lstlisting}

We cannot deconstruct a list with, for instance, a tuple pattern. Thus, such patterns are wrongly typed:
\begin{lstlisting}
{x, y} = xs      # wrong 
\end{lstlisting}

For maps we apply similar restrictions to the applied for lists; the type is $Map(t,(u_1,...,u_n))$, where $t$ is the type of the keys and $u_1$, ..., $u_n$ are the respective types of the $n$ elements.

One of the main objectives of the design of our type system is to be backward compatible, to allow working with legacy code. To do so we allow the existence of \emph{untyped functions}. An untyped function is a function that does not have an \texttt{@spec} specification. In fact, \texttt{Base.Math.dec} and \texttt{Main.fact}, previously defined, are untyped functions. We do not type check the definitions of such functions, and assign them the type $(Any, .., Any) \rightarrow Any$, where $Any$ is the supertype. 
%in the subtype relation. 
This type means that the function accepts arguments of any type and returns a value of the supertype $Any$.

The type $Any$ can also be used explicitly in the type specification of functions. This makes it possible to have some sort of \emph{poor man's (parametric) polymorphism}. For example, the following function calculates the length of a list:
%
\begin{lstlisting}
@spec length(List(any)) :: integer
def length([]) do  0 end
def length([head|tail]) do 1 + length(tail) end
\end{lstlisting}
%
Moreover, we can define the identity function, by using $Any$ as result type.
\begin{lstlisting}
@spec id(any) :: any
def id(x) do x end
\end{lstlisting}

The question that naturally arises is what we can do with those values (of type $Any$) returned by untyped functions or pseudo-polymorphic ones. By subtyping, values of type $Any$ can only be the argument of functions that expect values of type $Any$ as input (and any other). This seems somehow useless. Motivated by this fact, in the places where those returned values occur our type system will implicitly perform a downcast to a concrete type $t$ given by the context. 
This is based on the principle, usual in many OO languages, regarding the trust on downcast introductions. 
%The principle, usual in downcast situations in many OO languages, is to simply trust such use cases. 
This enables us to proceed with the typing process normally, but has the well-known risk that the introduction of a downcast may lead to a runtime error. 
%a type that can be used in any context. 
%To emphasize in their untyped character, we do not even type check their definitions.
For example, the following expression correctly typechecks after performing a downcast from $Any$ to $Integer$ and runs without any problem:
%
\begin{lstlisting}
id(8) + 10               # 18
\end{lstlisting}
%
However, the following expressions typecheck, but fail at runtime:
%
\begin{lstlisting}
"hello" <> Main.fact(9)  # runtime error
id(8) and true           # runtime error
\end{lstlisting}