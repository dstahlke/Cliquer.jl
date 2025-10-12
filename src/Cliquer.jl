module Cliquer

export find_single_clique, find_all_cliques
export find_single_independent_sets, find_all_independent_sets

using cliquer_jll, Graphs, Libdl

SetElement = Culong

l = cliquer_jll.libcliquer

function set_to_bitvec(s::Ptr{SetElement})::BitVector
    #@ccall l.wrap_set_print(s::Ptr{SetElement})::Cvoid
    N = @ccall l.wrap_set_max_size(s::Ptr{SetElement})::Cint
    return BitVector((@ccall l.wrap_set_contains(s::Ptr{SetElement}, i::Cint)::Cint) != 0 for i in 0:(N-1))
end

function find_all_callback(s::Ptr{SetElement}, cg::Ptr{Cvoid}, opts::Ptr{Cvoid})::Cint
    data_c = @ccall l.wrap_get_user_data(opts::Ptr{Cvoid})::Ptr{Cvoid}
    data = unsafe_pointer_to_objref(data_c)::CliquerContext
    data.userfunc(vertices(data.g)[set_to_bitvec(s)])
    return 1
end

function time_function_callback(level::Cint, i::Cint, n::Cint, max::Cint, user_time::Cdouble, system_time::Cdouble, opts::Ptr{Cvoid})::Cint
    data_c = @ccall l.wrap_get_user_data(opts::Ptr{Cvoid})::Ptr{Cvoid}
    data = unsafe_pointer_to_objref(data_c)::CliquerContext
    data.timefunc((level=level, i=i, n=n, max=max, user_time=user_time, system_time=system_time))
    return 1
end

mutable struct CliquerContext
    graphhandle::Ptr{Cvoid}
    optshandle::Ptr{Cvoid}
    timefunc::Function
    userfunc::Function
    g::Graphs.AbstractSimpleGraph

    function CliquerContext(userfunc::Function, g::Graphs.AbstractSimpleGraph, verbose::Union{Bool, Function}, weights::Vector{<:Integer})
        N::Cint = nv(g)
        graph_c = @ccall l.graph_new(N::Cint)::Ptr{Cvoid}

        if verbose == false
            verbose = s -> nothing
        end
        timefunc = (verbose isa Function) ? verbose : (s -> nothing)

        opts_c = @ccall l.wrap_create_opts()::Ptr{Cvoid}
        obj = new(graph_c, opts_c, timefunc, userfunc, g)
        finalizer(finalize_context, obj)

        if verbose isa Function
            time_function_callback_c = @cfunction(time_function_callback, Cint, (Cint, Cint, Cint, Cint, Cdouble, Cdouble, Ptr{Cvoid}))
            @ccall l.wrap_set_time_func(obj.optshandle::Ptr{Cvoid}, time_function_callback_c::Ptr{Cvoid})::Cvoid
        end
        find_all_callback_c = @cfunction(find_all_callback, Cint, (Ptr{SetElement}, Ptr{Cvoid}, Ptr{Cvoid}))
        @ccall l.wrap_set_user_func(obj.optshandle::Ptr{Cvoid}, find_all_callback_c::Ptr{Cvoid})::Cvoid
        @ccall l.wrap_set_user_data(obj.optshandle::Ptr{Cvoid}, obj::Any)::Cvoid

        if !isempty(weights)
            if length(weights) != N
                throw(ArgumentError("length of weights didn't match length of graph"))
            end
            for (i,w) in enumerate(weights)
                if w <= 0
                    throw(ArgumentError("vertex weights must be positive"))
                end
                @ccall l.wrap_set_weight(obj.graphhandle::Ptr{Cvoid}, (i-1)::Cint, w::Cint)::Cvoid
            end
        end

        for e in edges(g)
            a::Cint = src(e)-1
            b::Cint = dst(e)-1
            @ccall l.wrap_graph_add_edge(obj.graphhandle::Ptr{Cvoid}, a::Cint, b::Cint)::Cvoid
        end

        return obj
    end
end

function finalize_context(obj::CliquerContext)
    #@ccall printf("finalize graph\n"::Cstring)::Cint
    @ccall l.graph_free(obj.graphhandle::Ptr{Cvoid})::Cvoid
    @ccall l.wrap_free_opts(obj.optshandle::Ptr{Cvoid})::Cvoid
    obj.graphhandle = Ptr{Cvoid}()
    obj.optshandle = Ptr{Cvoid}()
end

"""
    find_single_clique(g::Graphs.AbstractSimpleGraph; verbose::Union{Bool,Function}=false, minweight::Integer=0, maxweight::Integer=0, maximal::Bool=true, weights::Vector{<:Integer}=Vector{Int32}())

Finds and returns a single clique meeting the given criteria (by default, a
maximum clique).

If `minweight=0`, it searches for maximum-weight cliques.  If `maxweight=0`,
there is no upper limit.  If `verbose=true`, progess messages will display; if
`verbose` is a function, that function gets called for every recursion with a
named tuple of status fields.
"""
function find_single_clique(g::Graphs.AbstractSimpleGraph; verbose::Union{Bool,Function}=false, minweight::Integer=0, maxweight::Integer=0, maximal::Bool=true, weights::Vector{<:Integer}=Vector{Int32}())
    ctx = CliquerContext(s->nothing, g, verbose, weights)
    minweight = Cint(minweight)
    maxweight = Cint(maxweight)
    maximal = Cint(maximal ? 1 : 0)
    if isempty(weights)
        GC.@preserve ctx s = @ccall l.clique_unweighted_find_single(ctx.graphhandle::Ptr{Cvoid},
            minweight::Cint, maxweight::Cint, maximal::Cint, ctx.optshandle::Ptr{Cvoid})::Ptr{SetElement}
    else
        GC.@preserve ctx s = @ccall l.clique_find_single(ctx.graphhandle::Ptr{Cvoid},
            minweight::Cint, maxweight::Cint, maximal::Cint, ctx.optshandle::Ptr{Cvoid})::Ptr{SetElement}
    end
    v = vertices(g)[set_to_bitvec(s)]
    @ccall l.wrap_set_free(s::Ptr{SetElement})::Cvoid
    return v
end

"""
    find_all_cliques(f::Function, g::Graphs.AbstractSimpleGraph; verbose::Union{Bool,Function}=false, minweight::Integer=0, maxweight::Integer=0, maximal::Bool=true, weights::Vector{<:Integer}=Vector{Int32}())::Int64

Finds and all cliques meeting the given criteria (by default, the maximum
cliques).  Calls the given callback for each clique.  Returns the number of
cliques found.

If `minweight=0`, it searches for maximum-weight cliques.  If `maxweight=0`,
there is no upper limit.  If `verbose=true`, progess messages will display; if
`verbose` is a function, that function gets called for every recursion with a
named tuple of status fields.
"""
function find_all_cliques(f::Function, g::Graphs.AbstractSimpleGraph; verbose::Union{Bool,Function}=false, minweight::Integer=0, maxweight::Integer=0, maximal::Bool=true, weights::Vector{<:Integer}=Vector{Int32}())::Int64
    ctx = CliquerContext(f, g, verbose, weights)
    minweight = Cint(minweight)
    maxweight = Cint(maxweight)
    maximal = Cint(maximal ? 1 : 0)
    if isempty(weights)
        GC.@preserve ctx numfound = @ccall l.clique_unweighted_find_all(ctx.graphhandle::Ptr{Cvoid},
            minweight::Cint, maxweight::Cint, maximal::Cint, ctx.optshandle::Ptr{Cvoid})::Cint
    else
        GC.@preserve ctx numfound = @ccall l.clique_find_all(ctx.graphhandle::Ptr{Cvoid},
            minweight::Cint, maxweight::Cint, maximal::Cint, ctx.optshandle::Ptr{Cvoid})::Cint
    end
    return numfound
end

"""
    find_all_cliques(g::Graphs.AbstractSimpleGraph; verbose::Union{Bool,Function}=false, minweight::Integer=0, maxweight::Integer=0, maximal::Bool=true, weights::Vector{<:Integer}=Vector{Int32}())::Vector{Vector{Int64}}

Finds and returns all cliques meeting the given criteria (by default, the
maximum cliques).

If `minweight=0`, it searches for maximum-weight cliques.  If `maxweight=0`,
there is no upper limit.  If `verbose=true`, progess messages will display; if
`verbose` is a function, that function gets called for every recursion with a
named tuple of status fields.
"""
function find_all_cliques(g::Graphs.AbstractSimpleGraph; verbose::Union{Bool,Function}=false, minweight::Integer=0, maxweight::Integer=0, maximal::Bool=true, weights::Vector{<:Integer}=Vector{Int32}())::Vector{Vector{Int64}}
    found = Vector{Int64}[]
    numfound = find_all_cliques(g; verbose=verbose, minweight=minweight, maxweight=maxweight, maximal=maximal, weights=weights) do s
        push!(found, s)
    end
    @assert length(found) == numfound
    return found
end

"""

    find_single_independent_sets(g::Graphs.AbstractSimpleGraph; verbose::Union{Bool,Function}=false, minweight::Integer=0, maxweight::Integer=0, maximal::Bool=true, weights::Vector{<:Integer}=Vector{Int32}())
Equivalent to `find_single_clique(complement(g))`.
"""
function find_single_independent_sets(g::Graphs.AbstractSimpleGraph; verbose::Union{Bool,Function}=false, minweight::Integer=0, maxweight::Integer=0, maximal::Bool=true, weights::Vector{<:Integer}=Vector{Int32}())
    find_single_clique(complement(g); verbose=verbose, minweight=minweight, maxweight=maxweight, maximal=maximal, weights=weights)
end

"""
    find_all_independent_sets(f::Function, g::Graphs.AbstractSimpleGraph; verbose::Union{Bool,Function}=false, minweight::Integer=0, maxweight::Integer=0, maximal::Bool=true, weights::Vector{<:Integer}=Vector{Int32}())::Int64

Equivalent to `find_all_cliques(f, complement(g))`.
"""
function find_all_independent_sets(f::Function, g::Graphs.AbstractSimpleGraph; verbose::Union{Bool,Function}=false, minweight::Integer=0, maxweight::Integer=0, maximal::Bool=true, weights::Vector{<:Integer}=Vector{Int32}())::Int64
    find_all_cliques(f, complement(g); verbose=verbose, minweight=minweight, maxweight=maxweight, maximal=maximal, weights=weights)
end

"""
    find_all_independent_sets(g::Graphs.AbstractSimpleGraph; verbose::Union{Bool,Function}=false, minweight::Integer=0, maxweight::Integer=0, maximal::Bool=true, weights::Vector{<:Integer}=Vector{Int32}())::Vector{Vector{Int64}}

Equivalent to `find_all_cliques(complement(g))`.
"""
function find_all_independent_sets(g::Graphs.AbstractSimpleGraph; verbose::Union{Bool,Function}=false, minweight::Integer=0, maxweight::Integer=0, maximal::Bool=true, weights::Vector{<:Integer}=Vector{Int32}())::Vector{Vector{Int64}}
    find_all_cliques(complement(g); verbose=verbose, minweight=minweight, maxweight=maxweight, maximal=maximal, weights=weights)
end

end # module Cliquer
