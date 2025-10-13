# Cliquer

[![Build Status](https://github.com/dstahlke/Cliquer.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/dstahlke/Cliquer.jl/actions/workflows/CI.yml?query=branch%3Amain)

Julia wrapper for [cliquer](https://users.aalto.fi/~pat/cliquer.html).
This finds cliques or independent sets in (possibly weighted) graphs.  It is much faster than the
clique finder in Graphs.jl.

    # By default, it finds the maximum weight clique.
    julia> find_single_clique(cycle_graph(5))
    2-element Vector{Int64}:
     2
     3

    # By default, it finds all maximum weight cliques.  This can be configured.
    julia> find_all_cliques(cycle_graph(5))
    5-element Vector{Vector{Int64}}:
     [2, 3]
     [3, 4]
     [4, 5]
     [1, 2]
     [1, 5]
