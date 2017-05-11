__precompile__()
module Annealing
    using Tsp.Model
    using Tsp.Debug
    using Base.Dates

    function find_optimal(;
        grid = (:required, "grid"),
        s0 = (:required, "s0"),
        T0 = (:required, "temp0"),
        limit::Int = 1000,
        starttime::DateTime = (:required, "starttime"),
        timelimit = -1
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
        for step in 0:limit
            if no_progress >= 25000
                no_progress = 0
                current = best
                reheats += 1
                @log @printf("[%10d] [T=%8e] No progress - restarting from best known position.\n", step, T)
                T = temp(cooldowns - Int(round(cooldowns/4)), T0)
            end
            candidate, i, j  = random_neighbour(current)

            diff = (candidate.score - s0.score) / s0.score * 100

            p::Float64 = probability(Float64(best.score), Float64(candidate.score), T)

            if p >= rand(0.0:0.0001:1.0)
                @info @printf("[%10d] [T=%8e] [p=%6.4f] Move: (%5d, %5d). New score: %.8f (%+.4f%%)\n",
                        step, T, p, i, j, candidate.score, diff)
                current = candidate
                T = nexttemp(T)
                cooldowns += 1
            elseif  candidate.score < current.score
                @info @printf("[%10d] [T=%8e] Switching to a better route: %.8f (%+.4f%%)\n",
                    step, T, candidate.score, diff)
                current = candidate
                T = nexttemp(T)
                cooldowns += 1
                last_progress = step
            else
                no_progress += 1
            end
            if current.score < best.score
                @log @printf("[%10d] [T=%8e] New best: %.8f (%+.4f%%)\n",
                  step, T, candidate.score, diff)
                best = candidate
                best_round = step
                no_progress = 0
            end

            if timeout(timelimit, starttime)
                println("timeout")
                return best
            end

            if T <= 1.0e-30
                @log @printf("Temperature reached 0, stopping search in round %d\n", step)
                last_round = step
                break
            end

            @log begin
                if step > 0 && step % 5000 == 0
                 @printf("[%10d] [T=%8e] [cd=%5d] [rh=%3d] last candidate: %.8f (%+.4f%%)\n",
                     step, T, cooldowns, reheats, candidate.score, diff)
                end
            end
        end

        @log @printf("Solution found in round %d\n", best_round)
        return best
    end

    function timeout(timeLimit::Dates.Period, startTime::DateTime)
        elapsed = now()-startTime
        return elapsed > Millisecond(timeLimit) - Millisecond(1000)
    end

    timeout(timeLimit::Int, startTime::DateTime) = false


    function random_neighbour(origin::Route)::Tuple{Route,Int,Int}
        newroute = Route(origin)

        i = rand(2:length(origin)-1)
        j = rand(2:length(origin)-1)
        while j == i
            j = rand(2:length(origin)-1)
        end

        idx = i < j ? (i:j) : (j:-1:i)
        newroute.score -= distance(newroute.route[i], newroute.route[i-1]) + distance(newroute.route[j], newroute.route[j+1])
        newroute.route[idx] = newroute.route[reverse(idx)]
        newroute.score += distance(newroute.route[i], newroute.route[i-1]) + distance(newroute.route[j], newroute.route[j+1])
        return newroute,i,j
    end

    function nexttemp(prev::Float64)::Float64
        prev * .995
    end

    function temp(cooldown::Int, t0::Float64)
        for i in 1:(cooldown > 0 ? cooldown : 0)
            t0 *= .995
        end
        t0
    end

    function probability(old::Float64, next::Float64, temp::Float64)
        delta =  next - old
        delta = 1.0/(1.0 + e ^ (delta / temp))
    end

    function check_args(args...)
        for arg in args
            if isa(arg, Tuple) && arg[1] == :required
                throw(ArgumentError("$(arg[2]) must be specified"))
            end
        end
    end

end