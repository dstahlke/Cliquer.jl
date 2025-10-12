module Cliquer

using cliquer_jll, Graphs, Libdl

SetElement = Culong

l = cliquer_jll.libcliquer
#sym_graph_new = dlsym(l, :graph_new)
#sym_graph_free = dlsym(l, :graph_free)
#sym_wrap_graph_add_edge = dlsym(l, :wrap_graph_add_edge)
#sym_graph_print = dlsym(l, :graph_print)
#sym_clique_unweighted_find_single = dlsym(l, :clique_unweighted_find_single)
#sym_clique_unweighted_find_all = dlsym(l, :clique_unweighted_find_all)
#sym_wrap_set_print = dlsym(l, :wrap_set_print)
#sym_wrap_set_free = dlsym(l, :wrap_set_free)
#sym_wrap_set_max_size = dlsym(l, :wrap_set_max_size)
#sym_wrap_set_contains = dlsym(l, :wrap_set_contains)
#sym_wrap_create_opts = dlsym(l, :wrap_create_opts)
#sym_wrap_free_opts = dlsym(l, :wrap_free_opts)
#sym_wrap_set_time_func = dlsym(l, :wrap_set_time_func)
#sym_wrap_set_user_func = dlsym(l, :wrap_set_user_func)
#sym_wrap_set_user_data = dlsym(l, :wrap_set_user_data)
#sym_wrap_get_user_data = dlsym(l, :wrap_get_user_data)

#default_opts = unsafe_load(convert(Ptr{Ptr{Cvoid}}, dlsym(l, :clique_default_options)))

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
find_all_callback_c = @cfunction(find_all_callback, Cint, (Ptr{SetElement}, Ptr{Cvoid}, Ptr{Cvoid}))

function time_function_callback(level::Cint, i::Cint, n::Cint, max::Cint, user_time::Cdouble, system_time::Cdouble, opts::Ptr{Cvoid})::Cint
    data_c = @ccall l.wrap_get_user_data(opts::Ptr{Cvoid})::Ptr{Cvoid}
    data = unsafe_pointer_to_objref(data_c)::CliquerContext
    data.timefunc((level=level, i=i, n=n, max=max, user_time=user_time, system_time=system_time))
    return 1
end
time_function_callback_c = @cfunction(time_function_callback, Cint, (Cint, Cint, Cint, Cint, Cdouble, Cdouble, Ptr{Cvoid}))

mutable struct CliquerContext
    graphhandle::Ptr{Cvoid}
    optshandle::Ptr{Cvoid}
    timefunc::Function
    userfunc::Function
    g::Graphs.AbstractSimpleGraph

    function CliquerContext(userfunc::Function, g::Graphs.AbstractSimpleGraph, verbose::Union{Bool, Function})
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
            @ccall l.wrap_set_time_func(obj.optshandle::Ptr{Cvoid}, time_function_callback_c::Ptr{Cvoid})::Cvoid
        end
        @ccall l.wrap_set_user_func(obj.optshandle::Ptr{Cvoid}, find_all_callback_c::Ptr{Cvoid})::Cvoid
        @ccall l.wrap_set_user_data(obj.optshandle::Ptr{Cvoid}, obj::Any)::Cvoid

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

function find_single(g::Graphs.AbstractSimpleGraph; verbose::Union{Bool,Function}=false)
    ctx = CliquerContext(s->nothing, g, verbose)
    GC.@preserve ctx s = @ccall l.clique_unweighted_find_single(ctx.graphhandle::Ptr{Cvoid}, 0::Cint, 0::Cint, 0::Cint, ctx.optshandle::Ptr{Cvoid})::Ptr{SetElement}
    v = vertices(g)[set_to_bitvec(s)]
    @ccall l.wrap_set_free(s::Ptr{SetElement})::Cvoid
    return v
end

function find_all(f::Function, g::Graphs.AbstractSimpleGraph; verbose::Union{Bool,Function}=false)::Int64
    ctx = CliquerContext(f, g, verbose)
    GC.@preserve ctx numfound = @ccall l.clique_unweighted_find_all(ctx.graphhandle::Ptr{Cvoid}, 0::Cint, 0::Cint, 0::Cint, ctx.optshandle::Ptr{Cvoid})::Cint
    return numfound
end

function find_all(g::Graphs.AbstractSimpleGraph; verbose::Union{Bool,Function}=false)::Vector{Vector{Int64}}
    found = Vector{Int64}[]
    find_all(g; verbose=verbose) do s
        push!(found, s)
    end
    return found
end

end # module Cliquer
