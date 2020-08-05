# Typed Elixir

## Básico

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

## Polimorfismo de subtipado

\subsection{Polimorfismo de subtipado}
En esta sección se describirá a través de ejemplos como se logra el polimorfismo a la hora de definir funciones, por lo que se podrá especificar el tipo de cualquier función, manteniendo la flexibilidad y esencia de lo que es Elixir.

Para definir una función que pueda ser aplicada para todos los tipos se debe anotar a los tipos de los parámetros como \textit{Any}. De esta forma cualquiera sea el tipo del parámetro con el que se llame siempre será subtipo de éste, ya que en la jerarquía de tipos \textit{Any} es el \textit{top type}. 

El siguiente ejemplo muestra una función polimórfica que retorna verdadero si el elemento que se pasa es igual a si mismo:

\begin{lstlisting}
@spec func12(any) :: boolean
def func12(x) do
    x == x
end
\end{lstlisting}

Algunos ejemplos de invocación a la función anterior son:

\begin{lstlisting}
func12([]) # true
func12(1) # true
func12("hola") # true
func12(%{:a => "a", :b => b}) # true
\end{lstlisting}

Cuando se quiere especificar una función para una lista de un determinado tipo (enteros por ejemplo), se puede hacer de la siguiente forma:

\begin{lstlisting}
@spec func13([integer]) :: integer
def func13([]) do
    0
end
def func13([head|tail]) do
    1 + func13(tail)
end
\end{lstlisting}

Algunos ejemplos de invocación a la función anterior son:

\begin{lstlisting}
func13([]) # 0
func13([1, 2, 3]) # 3

func13(["1", "2", "3"]) # error
func13([:uno, :dos, :tres]) # error
func13([1, :dos, "tres"]) # error
\end{lstlisting}

Acá se puede ver como la lista vacía no da error por ser del tipo \textit{List(Any)} y puede ser reducida al tipo \textit{List(Integer)} mediante la regla (TE\_DOWN).

Pero, si se quiere definir una función que sea aplicable a todas las listas, se debe indicar con el tipo \textit{List(Any)}.

La siguiente es una función que toma una lista y retorna su largo sin importar el tipo de sus valores:

\begin{lstlisting}
@spec func14([any]) :: integer
def func14([]) do
    0
end
def func14([head|tail]) do
    1 + func14(tail)
end
\end{lstlisting}

Algunos ejemplos de invocación a la función anterior son:

\begin{lstlisting}
func14([]) # 0
func14([1, 2, 3]) # 3
func14(["1", "2", "3"]) # 3
func14([:uno, :dos, :tres]) # 3

func14([1, :dos, "tres"]) # error
\end{lstlisting}

Las listas deben ser todas de un mismo tipo para ser construidas, es por esto que el último caso es erróneo. 

Para el caso de los mapas, si se quiere especificar una función sobre mapas donde sus claves sean átomos se puede hacer de la siguiente forma:

\begin{lstlisting}
@spec func15(%{atom => []}) :: boolean
def func15(map) do
    map[:key1] == :uno
end
\end{lstlisting}

Los mapas tienen un funcionamiento particular porque las claves siempre deben ser de un mismo tipo, por lo tanto una vez que se determina, todas las claves deben cumplirlo (mismo caso que las listas). Sin embargo, los valores pueden ser de tipos diferentes. Un mapa con más valores es subtipo de uno con menos, siempre y cuando se cumplan los tipos que sí están definidos para la clave y los valores. En este caso no se especificó el tipo de los valores del mapa por lo tanto cualquier tipo de mapa que cumpla el tipo de la clave será subtipo de éste tipo.

Ejemplos de invocación a la función anterior:

\begin{lstlisting}
func15(%{:key1=>1, :key2=>:dos, :key3=>"tres"}) # false
func15(%{:key1=>:uno, :key2=>:dos, :key3=>"tres"}) # true

func15(%{"1"=>:dos, "dos"=>:dos}) # error porque las claves no son atomos
func15(%{:key1=>:uno, "dos"=>:dos, 3=>:tres}) # error porque las claves son de distintos tipos
\end{lstlisting}

Si se quiere especificar una función que tome como parámetro mapas con cualquier tipo en su clave se debe indicar que éstas son de tipo \textit{None}. La siguiente función toma un mapa polimórfico y retorna verdadero si para la clave \textit{:key1} se tiene como valor el átomo \textit{:uno}:

\begin{lstlisting}
@spec func16(%{none => [any]}) :: boolean
def func16(map) do
    map[:key1] == :uno
end
\end{lstlisting}

Ejemplos de invocación a la función anterior son:

\begin{lstlisting}
func16(%{"uno"=>:uno, "dos"=>2, "tres"=>"Tres"}) # false
func16(%{"uno"=>1, "dos"=>2, "tres"=>3}) # false
func16(%{:key1=>:uno, :key2=>2, :key3=>"Tres"}) # true
func16(%{:key1=>:uno, :key2=>:dos, :key3=>:tres}) # false

func16(%{1=>:uno, :dos=>2, "tres"=>"Tres"}) # error porque las claves son de distintos tipos
\end{lstlisting}

Es necesario recordar que para el subtipado los mapas son covariantes en los tipos de los valores y contravariantes en los tipos de las claves. Un ejemplo de la relación de subtipado entre el tipo del mapa de la primer llamada con el tipo del parámetro de la función sería:

\begin{prooftree} 
\AxiomC{$None <: String \quad\quad Atom <: Any $}
\RightLabel{(ST\_MAP)}
\UnaryInfC{$Map(String \rightarrow (Atom, Integer, String)) <: Map(None \rightarrow (Any))$}
\end{prooftree}

Entonces, siendo $e = \%\{$ ``uno'' $\Rightarrow $ :uno $, $ ``dos'' $\Rightarrow $ 2 $, $ ``tres'' $ \Rightarrow $ "Tres" $ \}$, la regla de tipado para la llamada sería:

\begin{prooftree} 
\AxiomC{$\Delta(\rho_{1}.func16, 1) = Map(None,(Any)) \rightarrow Boolean $}
\noLine
\UnaryInfC{$\Delta; \Gamma; \rho_{1} \vdash^t e: Map(String \rightarrow (Atom, Integer, String)) \Rightarrow \Gamma$}
\noLine
\UnaryInfC{$Map(String \rightarrow (Atom, Integer, String)) <: Map(None \rightarrow (Any)) $}
\RightLabel{(TE\_APPFE)}
\UnaryInfC{$\Delta; \Gamma; \rho_{1} \vdash^t func16 \ (e) : Boolean \Rightarrow \Gamma $}
\end{prooftree}

Si se quiere definir una función que recibe una tupla donde uno de sus elementos sea cualquier tipo se debe especificar el tipo de ese valor como \textit{Any}. 

La siguiente función toma duplas donde el primer elemento puede ser de cualquier tipo mientras que el segundo debe ser un entero:

\begin{lstlisting}
@spec func16({any, integer}) :: boolean
def func16({x, y}) do
    y > 2
end
\end{lstlisting}

Ejemplos de invocación a la función anterior:

\begin{lstlisting}
func16({1, 1}) # false
func16({2, 3}) # true
func16({:dos, 3}) # true
func16({"uno", 4}) # true

func16({5,"tres"}) # error
\end{lstlisting}

Para no definir un tipo específico de retorno de una función se puede anotarlo como \textit{Any}. Por ejemplo, la siguiente función toma una lista de cualquier tipo y retorna su primer elemento:

\begin{lstlisting}
@spec func17([any]) :: any
def func17(list) do
    [head | tail] = list
    head
end
\end{lstlisting}

Ejemplos de invocación a la función anterior:

\begin{lstlisting}
func17(["uno", "dos", "tres"]) # "uno"
func17([1, 2, 3]) # 1
func17([:uno, :dos, :tres]) # :uno
func17([[1,2,3], [4,5,6], [7,8,9]]) # [1,2,3]
\end{lstlisting}

De la misma forma que lo hicimos para los parámetros, también podemos decir que el tipo de retorno será una lista pero de cualquier tipo, anotando el tipo de retorno como \textit{List(Any)}. El siguiente ejemplo muestra la especificación de una función que tiene como parámetro una lista de cualquier tipo y como retorno una lista (la cola) de la cual no se conoce su tipo:

\begin{lstlisting}
@spec func18([any]) :: [any]
def func18(list) do
    [head | tail] = list
    tail
end
\end{lstlisting}

Ejemplos de invocación a la función anterior:

\begin{lstlisting}
func18([1]) # []
func18([1,2]) # [2]
func18([1.1, 2.0]) # [2.0]
func18(["uno", "dos", "tres"]) # ["dos", "tres"]
func18([:uno, :dos]) # [:dos]
func18([{1,"uno"}, {2,"dos"}, {3,"tres"}]) # [{2,"dos"}, {3,"tres"}]
func18([%{1 => 3}, %{2 => "4"}, %{3 => :cinco}]) # [%{2 => "4"}, %{3 => :cinco}]
\end{lstlisting}

Como se mencionó, al brindarse esta flexibilidad mediante la regla (TE\_DOWN), es responsabilidad del desarrollador el uso de este tipo de funciones ya que por ejemplo, podríamos tener los siguientes usos:

\begin{lstlisting}
func13(func18([0,1]))
func13(func18(['a', 'b'])) 
\end{lstlisting}

Ambos ejemplos son válidos en tiempo de ejecución porque la función func13 requiere una lista de enteros y la función func18 retorna una lista de valores $any$. Por downcast se tiene:

\begin{prooftree} 
\AxiomC{$ \Delta; \Gamma; \rho \vdash^{t} func18([0,1]) : List(Any) \Rightarrow \Gamma^1 $}
\noLine
\UnaryInfC{$List(Integer) \lll List(Any) $}
\RightLabel{(TE\_DOWN)}
\UnaryInfC{$\Delta; \Gamma; \rho \vdash^{t} func18([0,1]) : List(Integer) \Rightarrow \Gamma^1 $}
\end{prooftree}

\begin{prooftree} 
\AxiomC{$ \Delta; \Gamma; \rho \vdash^{t} func18([$ `a'$,$ `b'$]) : List(Any) \Rightarrow \Gamma $}
\noLine
\UnaryInfC{$List(Integer) \lll List(Any) $}
\RightLabel{(TE\_DOWN)}
\UnaryInfC{$\Delta; \Gamma; \rho \vdash^{t} func18([$ `a'$,$ `b'$]) : List(Integer) \Rightarrow \Gamma $}
\end{prooftree}

Sin embargo, en tiempo de ejecución el segundo caso dará un error, por utilizar una lista de cadena de caracteres en una función que esperaba una lista de enteros.

De la misma forma se puede obtener este comportamiento para mapas y tuplas.
