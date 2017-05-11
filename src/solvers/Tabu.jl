module Tabu

    using Tsp.Model



    """
        find_optimal(cities, [kwargs])

    ## Arguments
    * cities - list of cities

    ## Keyword arguments
    * rounds - max number of iterations to perform [default: 100]
    * restart_after - number of rounds without progress before a jump to new solution space region [default: 5]
    * quit_after - max number of jumps before ending the search [default: 15]
    * min_tabu_duration - [default: sqrt(legth(cities))]
    """
    function find_optimal(
        grid::Grid;
        rounds::Int             = 1000,
        f_neighbours            = .2,
        n_neighbours            = round(Int, f_neighbours * length(grid.cities)),
        jump_radius             = div(length(grid.cities), 10),
        restart_after::Int      = 5,
        quit_after::Int         = 15,
        min_tabu_duration::Int  = min(div(rounds, 2), round(Int, sqrt(length(grid.cities)))),
        max_tabu_duration::Int  = 2 * min_tabu_duration
        )
        tic()
        #= println("""
            Initializing search:
                Rounds: $rounds
                Neighbourood size: $n_neighbours
                Neighbourhood radius: $jump_radius
                Restart after: $restart_after rounds
                Restart limit: $quit_after
                Tabu duration: $min_tabu_duration:$max_tabu_duration
                Jump radius: $jump_radius
            """)*/=#


        cities = grid.cities
        best::Route = nearest_neighbour(cities) # best solution so far
        best_round = 0
        origin::Route = best # solution from which the search currently progresses

        rounds_without_progress::Int = 0
        rounds_with_progress::Int = 0
        rounds_without_progress_strict::Int = 0
        jumps::Int64 = 0

        # save initial argument values
        initial_jump_radius = jump_radius
        initial_restart_after = restart_after
        initial_n_neighbours = n_neighbours
        initial_score = origin.score
        n_neighbours = min(length(cities)^2, n_neighbours)

        max_neighbours = min(length(cities) >= 10000 ? 5000 : n_neighbours * 2)

        max_restart_after = 2 * initial_restart_after

        # @debug "Initial solution: %10f (%.4fs)\n", score!(origin), toq()
        last_loop= 0 # last loop's time in seconds
        # The main loop
        time_elapsed = 0.0
        rounds_in_terrible_neighbourhood = 0
        for cur_round in 1:rounds
            tic()
            if rounds_without_progress_strict >= 10
                # @debug("[%5d] Not enough progress, forcing restart\n", cur_round)
                jumps += 1
                restart_after = initial_restart_after
                n_neighbours = initial_n_neighbours
                rounds_without_progress_strict = 0
                rounds_with_progress = 0
                rounds_without_progress = restart_after # force restart
            end
            # ignore terrible solutions faster
            if rounds_in_terrible_neighbourhood == 0 && (origin.score - initial_score)/initial_score * 100 > 100.0
                # @debug("Terrible solution (%+8.5f), not staying for long\n", (origin.score - initial_score)/initial_score * 100 > 100.0)
                rounds_in_terrible_neighbourhood += 1
                restart_after = min(0, 5 - floor(Int, origin.score - initial_score)/initial_score)
            end
            # change origin if there was no progress in the last restart_after rounds
            if rounds_without_progress + rounds_in_terrible_neighbourhood >= restart_after
                # println("[$cur_round] No progress for $rounds_without_progress rounds")
                if jumps >= quit_after # too many jumps - accept current best solution
                    # @debug("[%5d] Restart limit reached - stopping the search\n", cur_round)
                    break
                end
                origin = jump(origin, jump_radius) # get_neighbours(origin, 1, jump_radius*100, grid)[1][1]
                # println("[$cur_round] Restarting.\tNew origin: $(score!(origin)). Restarts: $jumps/$quit_after")
                # jump_radius += 1
                jumps += 1
                rounds_without_progress = min(restart_after, floor(Int, time_elapsed/240.0))
                rounds_with_progress = 0
                rounds_in_terrible_neighbourhood = 0
                restart_after = initial_restart_after
                n_neighbours = initial_n_neighbours
                # @printf("[%5d] Restarting: new origin: %10f (%+8.5f%%)\tRestarts: %d/%d, Time elapsed: %fs (+%d)\n",
                    # cur_round, score!(origin), (origin.score - initial_score)/initial_score * 100,
                    # jumps, quit_after, time_elapsed, rounds_without_progress)
            end

            if rounds_with_progress >= 5
                if restart_after < initial_restart_after
                    restart_after = initial_restart_after
                end
                if restart_after < max_restart_after
                    restart_after += round(Int, .5*restart_after)
                end
                if n_neighbours < max_neighbours
                    n_neighbours += round(Int, .1*n_neighbours)
                end
                rounds_without_progress = 0
                rounds_with_progress = 0
                # @printf("[%5d] Nice neighbourhood, extending search. New params:\n\tNeighbourood size: %d\n\tRestarting after: %d\n",
                    # cur_round, n_neighbours, restart_after)
                # println("[$cur_round] Nice neighbourhood, extending search. New params:
                #         Neighbourood size: $n_neighbours
                #         Restart after $restart_after rounds")
            end

            # tic() # neighbours
            neighbours = Task(()->get_neighbours(origin, n_neighbours, grid)) # "coroutine" to avoid allocating all the neighbours at once
            best_candidate::Route, best_i, best_j = first(neighbours)

            # search through the neighbours
            # tic()
            for (candidate, i, j) in neighbours

                if cities[i].tabu >= cur_round || cities[j].tabu >= cur_round
                    # check aspiration
                    penalty = 0.5 * abs((cities[i].tabu  + cities[j].tabu - cur_round*2))
                    # @debug("tabu: %16f, %d, %d, penalty = %d | best = %16f\n", score!(candidate),i, j, penalty, best.score)
                    if score!(candidate) + penalty < score!(best)
                        # @printf("[%5d] Found a great solution, ignoring tabu [%d,%d]: %10f (%+8.5f%%), swap: (%d, %d)\n",
                        #      cur_round, cities[i].tabu, cities[j].tabu, candidate.score, (candidate.score - initial_score)/initial_score * 100, i, j)
                        best_candidate, best_i, best_j = candidate, i, j
                        best = candidate
                        continue
                    end
                elseif score!(candidate) < score!(best_candidate)
                    best_candidate, best_i, best_j = candidate, i, j
                else
                    make_tabu(cities[i], min(
                        cur_round + div(min_tabu_duration, 2),
                        floor(Int, cur_round + rand(min_tabu_duration:max_tabu_duration) * (origin.score - initial_score)/initial_score * 100))
                    )
                    make_tabu(cities[j], min(
                        cur_round + div(min_tabu_duration, 2),
                        floor(Int, cur_round + rand(min_tabu_duration:max_tabu_duration) * (origin.score - initial_score)/initial_score * 100))
                    )
                end
            end

            # println("[Time][$cur_round] $n_neighbours neighbours checked in $(toq())s")
            # check best neighbour with the origin
            if score!(best_candidate) < score!(origin)
                # @debug("[%5d] New best neighbour: %10f (%+8.5f%%), swap: (%d, %d)\n", cur_round, best_candidate.score, (best_candidate.score - initial_score)/initial_score * 100, best_i, best_j)
                rounds_without_progress = 0
                origin = best_candidate

                if score!(origin) < score!(best)
                    # println("[$cur_round] New best solution: $(origin.score) ($((origin.score - initial_score)/initial_score * 100)%)")
                    # @info @printf("[%5d] New best solution: %10f (%+8.5f%%)\n", cur_round, origin.score, (origin.score - initial_score)/initial_score * 100)
                    best = origin
                    best_round = cur_round
                    rounds_without_progress_strict = 0
                else
                    rounds_without_progress_strict += 1
                end
            else
                rounds_without_progress += 1
            end
            round_time = toq()
            time_elapsed += round_time
            if (round_time > 0.1 || cur_round % 50 == 0)
                # @info("[%5d] %7.5fs\tbest: %10f\tround best: %10f (%+8.5f%%)\n",
                #      cur_round, round_time, best.score, best_candidate.score,
                #      (best_candidate.score - initial_score)/initial_score * 100)
            end
        end
        # @info @printf("Best solution found in round #%d\n", best_round)
        return best
    end #find_optimal

    function get_neighbours(origin::Route, n_neighbours::Int, grid::Grid)
        # neighbours = Array(Tuple{Route, Int, Int}, n_neighbours)
        n = 0
        cities = grid.cities
        while n < n_neighbours
            neighbour = Route(origin)
            i = rand(2:length(origin)-1)
            city = grid.cities[i]
            chunk = grid.chunks[city.chunk_x, city.chunk_y]
            if length(chunk.cities) < 2
                # println("WARNING: requested swap in a single-city chunk, ignoring")
                continue
            end
            j_id = rand(chunk.cities).id # id of city to swap ith city on route with
            # println("[swap: $i] indices: i=$i, j=$j")
            while j_id == city.id || j_id == 1 # ensure there is a swap
                # if canary >= 100
                #     println("WARNING: stuck selecting city to swap for 100 rounds")
                #     break
                # end
                j_id = rand(chunk.cities).id
                # canary += 1
            end
            j = findfirst(city->city.id == j_id, neighbour.route)
            # middle = i < j ? (i:j) : (i:-1:j)
            # println("old: $neighbour")
            # println("i=$i, j=$j")
            if i < j
                neighbour.score -= distance(neighbour.route[i], neighbour.route[i-1]) + distance(neighbour.route[j], neighbour.route[j+1])
                neighbour.route[i:j] = neighbour.route[reverse(i:j)]
                neighbour.score += distance(neighbour.route[i], neighbour.route[i-1]) + distance(neighbour.route[j], neighbour.route[j+1])
            else
                neighbour.score -= distance(neighbour.route[j], neighbour.route[j-1]) + distance(neighbour.route[i], neighbour.route[i+1])
                neighbour.route[j:i] = neighbour.route[reverse(j:i)]
                neighbour.score += distance(neighbour.route[j], neighbour.route[j-1]) + distance(neighbour.route[i], neighbour.route[i+1])
            end
            n += 1
            produce((neighbour, city.id, j_id)) # avoids allocating a shitload of paths for no good reason
        end
    end #get_neighbours

    function jump(origin::Route, jump_radius::Int)
        new_route = Route(origin)
        i = rand(2+jump_radius:length(origin)-1-jump_radius)
        j = rand(2:length(origin)-1)
        # println("$(i+jump_radius), $(length(origin)-1-jump_radius)")
        new_route.route[i-jump_radius:i+jump_radius] = shuffle(new_route.route[i-jump_radius:i+jump_radius])
        return new_route
    end #jump
end