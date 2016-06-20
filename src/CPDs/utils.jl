"""
    strip_arg(arg::Symbol)
Strip anything extra (type annotations, default values, etc) from an argument.
For now this cannot handle keyword arguments (it will throw an error).
"""
strip_arg(arg::Symbol) = arg # once we have a symbol, we have stripped everything, so we can just return it
function strip_arg(arg_expr::Expr)
    if arg_expr.head == :parameters # keyword argument
        error("strip_arg can't handle keyword args yet (parsing arg expression $(arg_expr))")
    elseif arg_expr.head == :(::) # argument is type annotated, remove the annotation
        return strip_arg(arg_expr.args[1])
    elseif arg_expr.head == :kw # argument has a default value, remove the default
        return strip_arg(arg_expr.args[1])
    else
        error("strip_arg encountered something unexpected. arg_expr was $(arg_expr)")
    end
end

"""
    required_func(signature)
Provide a default function implementation that throws an error when called.
"""
macro required_func(signature)
    if signature.head == :(=) # in this case a default implementation has already been supplied
        return esc(signature)
    end
    @assert signature.head == :call

    # get the names of all the arguments
    args = [strip_arg(expr) for expr in signature.args[2:end]]

    # get the name of the function
    fname = signature.args[1]

    error_string = "BayesNets.jl: No implementation of $fname for "

    # add each of the arguments to error string
    for (i,a) in enumerate(args)
        error_string *= "$a::\$(typeof($a))"
        if i == length(args)-1
            error_string *= ", and "
        elseif i != length(args)
            error_string *= ", "
        else
            error_string *= "."
        end
    end

    # if you are modifying this and want to debug, it might be helpful to print
    # println(error_string)

    body = Expr(:call, :error, parse("\"$error_string\""))

    return Expr(:function, esc(signature), esc(body))
end


"""
    sub2ind_vec{T<:Integer}(dims::Tuple{Vararg{Integer}}, I::AbstractVector{T})
The ordering of the parental instantiations in discrete networks follows the convention
defined in Decision Making Under Uncertainty.

Suppose a variable has three discrete parents. The first parental instantiation
assigns all parents to their first bin. The second will assign the first
parent (as defined in `parents`) to its second bin and the other parents
to their first bin. The sequence continues until all parents are instantiated
to their last bins.

This is a directly copy from Base.sub2ind but allows for passing a vector instead of separate items

Note that this does NOT check bounds
"""
function sub2ind_vec{T<:Integer}(dims::Tuple{Vararg{Integer}}, I::AbstractVector{T})
    N = length(dims)
    @assert(N == length(I))

    ex = I[N] - 1
    for i in N-1:-1:1
        if i > N
            ex = (I[i] - 1 + ex)
        else
            ex = (I[i] - 1 + dims[i]*ex)
        end
    end

    ex + 1
end

"""
    infer_number_of_instantiations{I<:Int}(arr::AbstractVector{I})
Infer the number of instantiations, N, for a data type, assuming that it takes on the values 1:N
"""
function infer_number_of_instantiations{I<:Int}(arr::AbstractVector{I})
    lo, hi = extrema(arr)
    lo ≥ 1 || error("infer_number_of_instantiations assumes values in 1:N, value $lo found!")
    lo == 1 || warn("infer_number_of_instantiations assumes values in 1:N, lowest value is $(lo)!")
    hi
end

"""
    consistent(a::Assignment, b::Assignment)
True if all common keys between the two assignments have the same value
"""
function consistent(a::Assignment, b::Assignment)

    for key in keys(a)
        if !haskey(b, key) || b[key] != a[key]
            return false
        end
    end

    true
end