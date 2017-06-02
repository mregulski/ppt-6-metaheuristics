module Genetic
    using Tsp.Model
    function find_optimal(grid)
    end

    function mutate(route::Route)::Route
          return Mutations.random_inversion(route)
    end

    function crossover(parents::Tuple{Route, Route})::Tuple{Route, Route}
        return Crossovers.OX(parents)
    end

    random_index(route::Route)::Int = rand(2:len(route.cities) - 1)

    function random_subrange(route::Route)::Tuple{Int,Int}
        i = random_index(route)
        j = random_index(route)
        while abs(i - j) < 3 || (len(route.cities) < 10 && i == j)
            j = random_index(route)
        end
        return min(i,j), max(i,j)
    end

    module Mutations
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

    module Crossovers
        function OX(parents::Tuple{Route, Route})::Tuple{Route, Route}
            core = random_subrange(parents[1])
            return _OX(parents[1], parents[2], core), _OX(parents[2], parents[1], section)
        end


        function _OX(routeA::Route, routeB::Route, core::Tuple{Int, Int})::Route
            first, last = core
            # init child as an empty route
            child = Route(Array(City, len(routeA)))
            child.route[1], child.route[len(routeA)] = routeA[1], routeA[1]
            isUsed = Dict(zip(routeA.cities, [false for x in routeA.cities]))
            child[first:last] = routeA[first:last]
            for city in child[first:last]
                isUsed[city] = true
            end
            println(child)
            for i in last+1:last+len(routeA) # iterate thorugh the whole array, but start at last+1

            end
        end
    end
end