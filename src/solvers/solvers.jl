module Solvers
    include("Tabu.jl")
    include("Anneal.jl")
    @enum SolverType tabu=1 annealing=2

    export solver

    for s in instances(SolverType)
        @eval export $(Symbol(s))
    end

    """
    Obtain a solver distance
    """
    function solver(kind::SolverType)::Function
        if kind == tabu
            return Tabu.find_optimal
        elseif kind == annealing
            return Annealing.find_optimal
        end
    end

end