include("Tsp.jl")
using Tsp.Model
using Tsp.Solvers
using Tsp.Debug
using Base.Dates

function params(n_cities, n_chunks)
    quit_after = 3
    rounds = 100
    if n_cities < 100
        n_neighbours = Int(.5 * (n_cities^2))
        restart_after = 75
    elseif n_cities < 1000
        n_neighbours = n_cities * 10
        restart_after = 50
    elseif n_cities < 10000
        rounds = 500
        n_neighbours = max(2500, round(Int, .5 * n_cities))
        restart_after = 45
        quit_after = 3
    else
        rounds = 200
        n_neighbours = 3000
        restart_after = 20
        quit_after = 3
    end

    min_tabu_duration = div(restart_after, 5)
    rounds = restart_after * quit_after * 2
    max_tabu_duration = min(ceil(Int, min_tabu_duration * 1.5), round(Int(rounds/quit_after)))
    jump_radius = round(Int, n_cities/(n_chunks * 2)) # half of avg chunk density
    return (rounds, restart_after, quit_after, min_tabu_duration, max_tabu_duration, n_neighbours, jump_radius)
end

function main(START)
    tic()
    # tic()
    cities, seconds = load_cities(STDIN)
    # toc()
    timelimit = seconds > 0 ? timeLimit = Second(seconds) : seconds

    # @log @printf("timelimit: %s\n", timeLimit)
    # println("loaded $(length(cities)) cities")
    # tic()
    grid = make_grid(cities)
    # toc()
    # x = Tsp.Debug.@config(Debug.DEBUG)
    # @log @printf("loaded grid\n")
    local route::Route
    method = Solvers.annealing
    solve = Solvers.solver(method)
    if method == Solvers.tabu
        rounds, restart_after, quit_after, min_tabu_duration, max_tabu_duration, n_neighbours, jump_radius = params(length(cities), length(grid.chunks))

        route = solve(grid,
                            rounds=rounds,
                            restart_after=restart_after,
                            quit_after=quit_after,
                            min_tabu_duration=min_tabu_duration,
                            max_tabu_duration=max_tabu_duration,
                            n_neighbours=n_neighbours,
                            jump_radius=jump_radius)

    elseif method == Solvers.annealing
        # tic()
        s0=nearest_neighbour(grid.cities)
        toc()
        tic()
        route = solve(
            grid=grid,
            s0=s0,
            # s0=Route([grid.cities[1], shuffle(grid.cities[2:end-1])..., grid.cities[1]]),
            T0=1000.0,
            limit=10000000,
            starttime=START,
            timelimit=timelimit)
        toc()
        println("initial solution: ", s0.score)
    end
    println("final solution: ", route.score)

    tic()
    println(STDOUT, route.score)
    for city in route.route
            println(STDERR, city.id)
    end
    toc()
    println(now()-START)

end

main(now())