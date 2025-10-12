using Cliquer
using Test
using Graphs
using IterTools

function kneser_graph(n::Integer, k::Integer)
    ss = collect(subsets(1:n, k))
    return SimpleGraph([isdisjoint(a, b) for a in ss, b in ss])
end

function cube13_graph()
    verts = map(x -> [x...], vcat(Iterators.product(map(x->[-1,0,1], 1:3)...)...))
    verts = filter(x -> !all(x .== 0), verts)
    verts = filter(x -> x > -x, verts)
    return Graph([ a'*b == 0 for a in verts, b in verts ])
end

function baseline_cliques(G)
    v = maximal_cliques(G)
    ω = maximum(length, v)
    v = filter(c -> length(c) == ω, v)
    v = sort(sort.(v))
    return v
end

function queens_graph(n::Integer, m::Integer)
    g = SimpleGraph(n*m)
    for (ix, iy, jx, jy) in Iterators.product(1:n, 1:m, 1:n, 1:m)
        dx = ix - jx
        dy = iy - jy
        if dx != 0 || dy != 0
            if dx == 0 || dy == 0 || dx == dy || dx == -dy
                add_edge!(g, (ix-1)*m + iy, (jx-1)*m + jy)
            end
        end
    end
    return g
end

@testset "Cliquer.jl" begin
    @test length(find_single_clique(kneser_graph(12,4) |> complement)) == binomial(12-1,4-1)
    @test sort(find_all_cliques(cube13_graph())) == baseline_cliques(cube13_graph())
    @test sort(find_all_independent_sets(cube13_graph())) == baseline_cliques(cube13_graph() |> complement)
    @test sort(find_all_cliques(queens_graph(8,8))) == baseline_cliques(queens_graph(8,8))
    @test sort(find_all_independent_sets(queens_graph(8,8))) == baseline_cliques(queens_graph(8,8) |> complement)
end
