__precompile__()
module Genetic
    using Tsp.Model
    using Tsp.Solvers
        using Base.Dates

    breed(population::Array{Route})::Array{Route} = proportional_breed(population)
    # breed(population::Array{Route})::Array{Route} = det_tournament_breed(population)

    crossover(parentA::Route, parentB::Route) = Recombinations.OX(parentA, parentB)

    mutate(route::Route)::Route = Mutations.random_inversion(route)

    # trim(population, target_size) = weighted_random_trim(population, target_size)
    trim(population, target_size) = elitist_trim(population, target_size)




    """
    grid            - TSP instance data
    pop_size        - population size
    max_generations - hard limit on the number of generations to test
    stall_limit     - hard limit on the number of generations without any progress. Search is stopped if this limit is reached

    """
    function find_optimal(grid,startTime,timeLimit;
        pop_size=100,
        max_generations=100,
        stall_limit=50,
        time_limit = NaN,
        init_mutation_p=.25,
        use_nn=false,)
        if use_nn
            nn = nearest_neighbour(grid.cities)
            random_count = Int(floor(pop_size * .5))
            random_nn_count = length(grid.cities) > 1000 ? 0 : Int(floor(pop_size) * .35)

            nn_count = pop_size - random_count - random_nn_count
            population = init_population(grid, random_count)
            append!(population, [nearest_neighbour(grid.cities, .05) for i in 1:random_nn_count])
            append!(population, [nn for i in 1:nn_count])
        else
            population = init_population(grid, pop_size)
        end
        best = alpha = findmax(population)[1]
        best_gen = 0
        stalling = 0
        mutation_prob = init_mutation_p
        last_reset = 0
        diversity = 1
        low_div_gens = 0
        try
            for gen in 1:max_generations
                children = breed(population)
                if diversity < .15
                    mutation_prob = (.5-diversity)*10 * init_mutation_p * (1 - 2*(gen-last_reset)/max_generations)
                    mutate!(population, mutation_prob)
                    low_div_gens += 1
                    # mutate!(population, mutation_prob)
                    # mutate!(population, mutation_prob)
                # elseif diversity < .5
                #     mutation_prob = (.5-diversity)*5 * init_mutation_p * (1 - 4*(gen-last_reset)/max_generations)
                #     # mutate!(kids, mutation_prob)
                else
                    mutation_prob = init_mutation_p * (1 - (gen-last_reset)/max_generations)
                    low_div_gens = 0
                end
                mutate!(children, mutation_prob)
                append!(population, children)
                alpha = bestof(population)
                diversity = length(unique(x->x.score, population))/length(population)

                @printf("[G: %5d] [S: %3d] [D: %6.2f%%] mutation: %6.3f%% | alpha: %13.6f | gen_avg: %13.6f | best: %13.6f\n", gen, stalling, diversity*100, mutation_prob*100, alpha.score, total_length(population)/length(population), best.score)
                if alpha.score < best.score
                    best = alpha
                    best_gen = gen
                    stalling = 0
                    # for i in 1:pop_size/10
                    #     idx = rand(1:length(population))
                    #     extras = crossover(alpha, population[idx])
                    #     append!(population, extras)
                    # end
                else
                    stalling += 1
                end
                population = trim(population, pop_size)

                if low_div_gens > 50 ||                                 ### very low diversity
                    (gen > 100 && stalling > .5 * gen) ||                ### no improvement in the beginning
                    stalling > stall_limit ||                           ### no improvement for too long
                    now() - startTime > Millisecond(div(timeLimit,2))   ### timeout
                    break
                end
            end
        catch ex
            if isa(ex, InterruptException)
                ### ignore
            else
                showerror(STDERR, ex, catch_backtrace())
            end
        end
        return best

    end

    # function boost_diversity() end
    function frequencies(population::Array{Route})::Dict{Float64,Int}
        freqs = Dict{Float64,Int}()
        for p in population
            @inbounds freq[p.score] = get(freq, p.score, 0) + 1
        end
        return freqs
    end

    function bestof(population::Array{Route})::Route
        best = population[1]
        for m in population
            if m.score < best.score
                best = m
            end
        end
        return best
    end

    """
    Obtain child routes from the choses routes
    Fitness proportionate selection
    """
    function proportional_breed(population::Array{Route})::Array{Route}
        children = Array(Route, Int(floor(length(population))))
        total = total_length(population)
        pop_size = length(population)
        ctr = 0
        for i in 1:2:length(children)
            idxA = idxB = 0
            while true
                ctr += 1
                ### pick a random solution and check if it's good enough
                idxA = rand(1:pop_size)
                if (rand() < 1 - population[idxA].score/total)
                    break
                end
            end
            while true
                ctr += 1
                ### pick a random solution and check if it's good enough
                idxB = rand(1:pop_size)
                if idxB != idxA && (rand() < 1 - population[idxB].score/total)
                    break
                end
            end
            if i + 1 <= length(children)
                children[i], children[i+1] = crossover(population[idxA], population[idxB])
            else ### ignore last child
                children[i] = crossover(population[idxA], population[idxB])[1]
            end
        end
        return children
    end

    function det_tournament_breed(population::Array{Route})::Array{Route}
        tournament_size = 10
        children = Array(Route, Int(floor(length(population))))
        for i in 1:2:length(children)
            parentA = _det_tournament_select(population, tournament_size)
            parentB = _det_tournament_select(population, tournament_size)
            if i + 1 <= length(children)
                children[i], children[i+1] = crossover(parentA, parentB)
            else # ignore last child
                children[i] = crossover(parentA, parentB)[1]
            end
        end
        return children
    end

    function ndet_tournament_breed(population::Array{Route})::Array{Route}
        zeros(Route,0)
    end


    function _det_tournament_select(population::Array{Route}, tournament_size::Int)::Route
        best::Route = rand(population)
        for i in 1:tournament_size-1 ### already done first step above
            challenger = rand(pop)
            if challenger.score < best.score
                best = challenger
            end
        end
        return best
    end

    function _make_tournament(population::Array{Route}, size::Int)::Array{Route}
        tournament = Array(Route, size)
        for i in 1:size
            tournament[i] = rand(population)
        end
        return tournament
    end

    function mutate!(kids::Array{Route}, prob::Float64)
        for kid in kids
            if  length(kid) > 30 && rand() < prob/2
                ends = random_subrange(kid, min_length=5, margin=5)
                kid[ends[1]-2:ends[1]+2], kid[ends[2]-2:ends[2]+2] = kid[ends[2]-2:ends[2]+2], kid[ends[1]-2:ends[1]+2]
            elseif rand() < prob
                ends = random_subrange(kid)
                kid[ends[1]], kid[ends[2]] = kid[ends[2]], kid[ends[1]]
            end
        end
    end

    """
    Kill off some routes to maintain population size
    """
    function weighted_random_trim(population, target_size)
        survivors = Array(Route, target_size)
        pop_size = length(population)
        total = total_length(population)
        idx = 0
        for i in 1:target_size
            while true
                ### pick a random solution and check if it's good enough
                idx = rand(1:pop_size)
                if (rand() < population[idx].score/total)
                    break
                end
            end
            survivors[i] = population[idx]
        end
        return survivors
    end

    function elitist_trim(population, target_size)
        return sort(population, by=x->x.score)[1:target_size]
        # return append!(sort(population, by=x->x.score)[1:div(target_size, 2)], weighted_random_trim(population, div(target_size,2)))
    end


    function total_length(population::Array{Route})::Float64
        ### map-reduce is way slower
        total = 0
        for p in population
            total += p.score
        end
        return total
    end




    function init_population(grid::Grid, size::Int)
        population = Array(Route, size)
        for i in 1:size
            route = push!(append!([grid.cities[1]], shuffle(grid.cities[2:end])), grid.cities[1])
            population[i] = Route(route)
        end
        return population
    end

    random_index(route::Route,margin::Int)::Int = rand(1+margin:length(route.cities) - margin)

    function random_subrange(route::Route; min_length::Int=3, max_length::Int=10, margin::Int=1)::Tuple{Int,Int}
        i = random_index(route,margin)
        j = random_index(route, margin)
        while abs(i - j) < min_length || abs(i - j) > max_length || (length(route.cities) < 10 && i == j)
            j = random_index(route, margin)
        end
        return min(i,j), max(i,j)
    end

    module Mutations
        using Tsp.Model
        import Tsp.Solvers.Genetic.random_subrange
        function random_inversion(route::Route)::Tuple{Route, Int, Int}
            i,j = random_subrange(route)
            first, last = route.cities[i], route.cities[j]
            mutated = Route(route)
            mutated.score -= distance(route.cities[i], route.cities[i-1])
                            + distance(route.cities[i], route.cities[i+1])
                            + distance(route.cities[j], route.cities[j-1])
                            + distance(route.cities[j], route.cities[j+1])
            mutated.cities[i], mutated.cities[j] = mutated.cities[j], mutated.cities[i]
            mutated.score += distance(route.cities[i], route.cities[i-1])
                            + distance(route.cities[i], route.cities[i+1])
                            + distance(route.cities[j], route.cities[j-1])
                            + distance(route.cities[j], route.cities[j+1])
            return mutated, i, j
        end
    end

    module Recombinations
        using Tsp.Model
        import Tsp.Solvers.Genetic.random_subrange


        function OX(parentA::Route, parentB::Route)::Tuple{Route, Route}
            # max_length = Int(floor(.1*(length(parentA))))
            core = random_subrange(parentA, min_length=5, max_length=length(parentA))
            return _OX(parentA, parentB, core)
        end

        """
            Performs two-way Order Crossover to produce 2 child routes from parents.

            http://www.sc.ehu.es/ccwbayes/docencia/kzmm/files/AG-TSP-operadoreak.pdf, pp. 140-141

            `routeA`. `routeB` - parent routes
            `core`             - range of positions to be copied from parents to children without changes
        """
        function _OX(routeA::Route, routeB::Route, core::Tuple{Int, Int})::Tuple{Route,Route}
            first, last = core
            len = length(routeA) ### note: == length(routeB)
            # println("core section: $core")
            ### init child as an empty route
            childA = zeros(City, len)
            childB = zeros(City, len)
            childA[1], childA[len] = routeA[1], routeA[1]
            childB[1], childB[len] = routeA[1], routeA[1]

            isUsedA = Dict(zip(routeA.cities, [false for x in routeA.cities]))
            isUsedB = Dict(zip(routeA.cities, [false for x in routeA.cities]))
            childA[first:last] = routeA[first:last]
            childB[first:last] = routeB[first:last]
            for city in childA[first:last]
                isUsedA[city] = true
            end
            for city in childB[first:last]
                isUsedB[city] = true
            end
            isUsedA[childA[1]] = isUsedB[childB[1]] = true
            if last + 1 == 1 || last + 1 == len
                next_child_posA = next_child_posB = 2
            else
                next_child_posA = next_child_posB = last + 1
            end
            for i in 1:len
                pos = (last + i - 1) % (len) + 1
                if pos == 1 || pos == len
                    continue
                end
                ### if the city is not used in the child yet, put it in the first empty place
                if !isUsedA[routeB[pos]]
                    childA[next_child_posA] = routeB[pos]
                    # println("inserting $(routeB[pos].id) at position $next_child_posA")
                    next_child_posA = (next_child_posA) % (len) + 1
                    ### make sure we don't change first or last position on the route;
                    ### it's required that child[1].id == child[:last].id == 1
                    if next_child_posA == 1 || next_child_posA == len
                        next_child_posA = 2
                    end
                end
                if !isUsedB[routeA[pos]]
                    childB[next_child_posB] = routeA[pos]
                    # println("inserting $(routeA[pos].id) at position $next_child_posB")
                    next_child_posB = (next_child_posB) % (len) + 1
                    ### make sure we don't change first or last position on the route;
                    ### it's required that child[1].id == child[:last].id == 1
                    if next_child_posB == 1 || next_child_posB == len
                        next_child_posB = 2
                    end
                end
            end
            return Route(childA),Route(childB)
        end
    end


end