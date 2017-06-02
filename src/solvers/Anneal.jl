__precompile__()
module Annealing
    using Base.Dates
    using Tsp.Model
    using Tsp.Debug

    function find_optimal(;
        grid = (:required, "grid"),
        s0 = (:required, "s0"),
        T0 = (:required, "temp0"),
        limit::Int = 1000,
        starttime = (:required, "starttime"),
        timelimit = -1,
        cooling_factor=0.997
    )

        check_args(grid, s0, T0, starttime)
        current::Route = s0
        best::Route = current
        best_round::Int = 0
        last_round::Int = 0
        T::Float64 = T0

        no_progress = 0
        cooldowns = 0
        reheats = 0

        init_reheat_threshold = 50000
        T0 += length(grid.cities)/1000 * 10
        cooling_factor -= length(grid.cities)/1000 * .003
        # if length(grid.cities) > 10000
        #     init_reheat_threshold = 100000
        # elseif length(grid.cities > 8000)


        reheat_threshold = init_reheat_threshold

        for step in 0:limit
            if no_progress >= reheat_threshold && reheats < 30
                reheat_threshold = init_reheat_threshold
                no_progress = 0
                current = best
                reheats += 1
                @info @printf("[%10d] [T=%8e] No progress - restarting from best known position.\n", step, T)

                T = T0/(reheats+5)
                if length(grid.cities) > 4000
                    cooling_factor -= .0001
                end
                # T=T0/(reheats*5)
                # T=temp(cooldowns - Int(round(cooldowns/2)), T0)
            end
            candidate, i, j  = random_neighbour(current, T, grid)

            diff = (candidate.score - s0.score) / s0.score * 100

            p::Float64 = probability(Float64(best.score), Float64(candidate.score), T)

            if p >= rand(0.0:0.0001:1.0)
                @info @printf("[%10d] [T=%8e] [p=%g] Move: (%5d, %5d). New score: %.8f (%+.4f%%)\n",
                        step, T, p, i, j, candidate.score, diff)
                current = candidate
                T = temp(T, cooling_factor)
                cooldowns += 1
            elseif candidate.score < current.score
                # @debug @printf("[%10d] [T=%8e] Switching to a better route: %.8f (%+.4f%%)\n",
                #     step, T, candidate.score, diff)
                current = candidate
                T = temp(T, cooling_factor)
                cooldowns += 1
                last_progress = step
                # reheat_threshold += 1000
            else
                no_progress += 1
            end
            if current.score < best.score
                reheat_threshold = init_reheat_threshold*5
                @log @printf("[%10d] [T=%8e] New best: %.8f (%+.4f%%)\n",
                  step, T, candidate.score, diff)
                best = candidate
                best_round = step
                no_progress = 0
            end

            done, elapsed = timeout(timelimit, starttime)
            if done
                @log @printf("[%10d] Timeout (%s)\n", step, elapsed)
                return best
            end

            if T <= 1.0e-6
                @log @printf("Temperature reached 0, stopping search in round %d\n", step)
                last_round = step
                break
            end

            if step > 0 && step % 50000 == 0
                @info @printf("[%10d] [T=%8e] [cd=%5d] [rh=%3d] last candidate: %.8f (%+.4f%%)\n",
                    step, T, cooldowns, reheats, candidate.score, diff)
            end
        end

        @log @printf("Solution found in round %d\n", best_round)
        return best
    end

    function timeout(timeLimit::Dates.Period, startTime::DateTime)
        elapsed = now()-startTime
        return elapsed > Millisecond(timeLimit) - Millisecond(1000), elapsed
    end

    timeout(timeLimit::Int, startTime::DateTime) = false, 0


    function random_neighbour(origin::Route, T::Float64, grid::Grid)::Tuple{Route,Int,Int}
        s1 = 1 + (rand(0:0.0001:0.01)) * origin.score
        s2 = 1 - (rand(0:0.0001:0.01)) * origin.score
        # if rand(0:0.0001:1.0) >= probability(s1, s2, T)
            _random_neighbour(origin)
        # else
            # _chunk_neighbour(origin, grid)
        # end
    end

    function _random_neighbour(origin::Route)::Tuple{Route,Int,Int}
        newroute = Route(origin)

        i = rand(2:length(origin)-1)
        j = rand(2:length(origin)-1)
        while j == i
            j = rand(2:length(origin)-1)
        end


        _reverse!(newroute, i, j)
        return newroute,i,j
    end

    function _chunk_neighbour(origin::Route, grid::Grid)::Tuple{Route,Int,Int}
        newroute = Route(origin)
        i = rand(2:length(origin)-1)
        src_city = newroute.cities[i]
        chunk = grid.chunks[src_city.chunk_x, src_city.chunk_y]
        if length(chunk.cities) < 2
            return _random_neighbour(origin)
        end

        dst_city = rand(chunk.cities)
        while dst_city.id == src_city.id || dst_city.id == 1
            dst_city = rand(chunk.cities)
        end

        j = findfirst(city->city.id == dst_city.id, newroute.cities)
        println("-------")
        println(grid.cities[i])
        println(grid.cities[j])
        println("-------")
        _swap!(newroute, i, j)
        return newroute, i,j
    end

    function _reverse!(route, i, j)
        idx = i < j ? (i:j) : (j:i)
        route.score -= distance(route.cities[first(idx)], route.cities[first(idx)-1]) + distance(route.cities[last(idx)], route.cities[last(idx)+1])
        route.cities[idx] = route.cities[reverse(idx)]
        route.score += distance(route.cities[first(idx)], route.cities[first(idx)-1]) + distance(route.cities[last(idx)], route.cities[last(idx)+1])
        route
    end

    function _swap!(route, i, j)
        route.score -= distance(route.cities[i], route.cities[i-1])
                    + distance(route.cities[i], route.cities[i+1])
                    + distance(route.cities[j], route.cities[j-1])
                    + distance(route.cities[j], route.cities[j+1])

        route.cities[i], route.cities[j] = route.cities[j], route.cities[i]

        route.score += distance(route.cities[i], route.cities[i-1])
                    + distance(route.cities[i], route.cities[i+1])
                    + distance(route.cities[j], route.cities[j-1])
                    + distance(route.cities[j], route.cities[j+1])
        route
    end

    """ get new temperature based on current value """
    temp(prev::Float64, rate::Float64)::Float64 = prev * rate

    """ get the temperature after n cooldowns """
    temp(n::Int, rate::Float64, T0::Float64) = n > 0 ? T0 * rate^n : T0

    # """
    #     Get the estimated temperature after given cooldown
    # """
    # temp(cooldown::Int, t0::Float64) = cooldown > 0 : t0 * rate^cooldown

    function probability(old::Float64, next::Float64, temp::Float64)
        delta =  next - old
        return 1.0/(1.0 + e ^ (delta / temp))
    end

    function check_args(args...)
        for arg in args
            if isa(arg, Tuple) && arg[1] == :required
                throw(ArgumentError("$(arg[2]) must be specified"))
            end
        end
    end

end