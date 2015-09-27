## Alternate constructors for symbolic objects
##
## Many (too many) ways to create symbolobjects
## Sym("x"), Sym(:x), Sym("x", "y") or Sym(:x, :y), @syms x y, symbols("x y")

"Create a symbolic object from a symbol or string"
Sym(s::@compat Union{Symbol, String}) = sympy_meth(:symbols, string(s))

"Create a symbolic number"
Sym{T <: Number}(x::T) = convert(Sym, x)

## math constants in math.jl and done in __init__ stage

"vectorized version of `Sym`"
Sym(args...) = map(Sym, args)

## (a,b,c) = @syms a b c --- no commas on right hand side!
## (x,) @syms x is needed for single arguments
## Thanks to vtjnash for this!
"""

Macro to create many symbolic objects at once. (Written by `@vtjnash`.)

Example: ` @syms a b c`

"""
macro syms(x...)
    q=Expr(:block)
    if length(x) == 1 && isa(x[1],Expr)
        @assert x[1].head === :tuple "@syms expected a list of symbols"
        x = x[1].args
    end
    for s in x
        @assert isa(s,Symbol) "@syms expected a list of symbols"
        push!(q.args, Expr(:(=), s, Expr(:call, :Sym, Expr(:quote, s))))
           end
    push!(q.args, Expr(:tuple, x...))
    q
end

"""

The `vars` macro is like `syms` except it assigns the variables into `Main`, so can be
called as `@vars a b c`. This simplifies construction of variables, but pollutes the `Main` module.

"""
macro vars(x...)
    q=Expr(:block)
    if length(x) == 1 && isa(x[1],Expr)
        @assert x[1].head === :tuple "@vars expected a list of symbols"
        x = x[1].args
    end
    for s in x
        @assert isa(s,Symbol) "@vars expected a list of symbols"
        push!(q.args, Expr(:(=), s, Expr(:call, :Sym, Expr(:quote, s))))
    end
    push!(q.args, Expr(:tuple, x...))
    eval(Main, q)
end


#macro sym_str(x)
#    Sym(x)
#end

##@deprecate sym_str(x)  symbols(x::String)

## define one or more symbols directly
## a,b,c = symbols("a,b,c", commutative=false)
"""

Function to create one or more symbolic objects. These are specified with a string,
with commas separating different variables.

This function allows the passing of assumptions about the variables
such as `positive=true`, `real=true` or `commutative=true`. See [SymPy Docs](http://docs.sympy.org/dev/modules/core.html#module-sympy.core.assumptions) for a complete list.

Example:

```
x,y,z = symbols("x, y, z", real=true)
```

"""

function symbols(x::String; kwargs...) 
    out = sympy_meth(:symbols, x; kwargs...)
end

function length(x::SymbolicObject)
    sz = size(x)
    length(sz) == 0 && return(0)
    *(sz...)
end
function size(x::SymbolicObject)
    return ()
end
function size(x::SymbolicObject, dim::Integer)
    if dim <= 0
        error("dimension out of range")

    else
        return 1
    end
end

## pull out x property of Sym objects or leave alone
project(x::Any) = x
project(x::SymbolicObject) = x.x
project(x::Symbol) = project(Sym(x)) # can use :x instead of Sym(x)
project(x::Tuple) = map(project, x)
function project{T <: Any}(x::Dict{Sym,T})
    D = Dict()
    for (k,v) in x
        D[project(k)] = v
    end
    D
end
project(x::MathConst{:π}) = project(convert(Sym, x))
project(x::MathConst{:e}) = project(convert(Sym, x))
project(x::MathConst{:γ}) = project(convert(Sym, x))
project(x::MathConst{:catalan}) = project(convert(Sym, x))
project(x::MathConst{:φ}) = project(convert(Sym, x))

## for size of containers
function length(x::SymbolicObject)
    sz = size(x)
    length(sz) == 0 && return(0)
    *(sz...)
end
function size(x::SymbolicObject)
    return ()
end
function size(x::SymbolicObject, dim::Integer)
    if dim <= 0
        error("dimension out of range")
   
    else
        return 1
    end
end


## Iterator for Sym
Base.start(x::Sym) = 1
Base.next(x::Sym, state) = (x.x, state-1)
Base.done(x::Sym, state) = state <= 0






"""
convert args so that we can use obj[:methname](x,...) without needing to project to
python: obj.method(arg1, arg2, ...) -> julia: obj[:meth](args...)

Examples:
```
x = Sym("x")
(x^2 - 2x + 1)[:diff]()
(x^2 - 2x + 1)[:integrate]((x,0,1))
```

"""
function getindex(x::SymbolicObject, i::Symbol)
    ## find method
    if haskey(project(x), i)
        out = project(x)[i]
        if isa(out, Function)
            function f(args...;kwargs...)
                out(project(args)...; [(k,project(v)) for (k,v) in kwargs]...)
            end
            return f
        else
            return out
        end
    elseif haskey(sympy, i)
        out = sympy[i]
        if isa(out, Function) 
            function f(args...;kwargs...) 
                out(project(x), project(args)...; [(k,project(v)) for (k,v) in kwargs]... )
            end
            return f
        else
            return out
        end
    else
        MethodError()
    end
end



## Helper function from PyCall.pywrap:
function members(o::@compat Union{PyObject, Sym})
    out = convert(Vector{(String,PyObject)},
                  pycall(PyCall.inspect["getmembers"], PyObject, project(o)))
    String[u[1] for u in out]
end

