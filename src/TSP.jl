__precompile__()
module Tsp
    module Debug
        @enum Level OFF=-1 ERROR=1 WARN LOG INFO DEBUG

        LEVEL = LOG
        export @debug, @info, @log, @warn, @error OFF, ERROR, WARN, INFO, DEBUG

        for (mac, lvl) in ((:debug, DEBUG),
                            (:info, INFO),
                            (:log, LOG),
                            (:warn, WARN),
                            (:error, ERROR))
                @eval macro $mac(expr)
                     LEVEL >= $lvl ? esc(expr) : esc(:nothing)
                end
            end
    end

    include("util.jl")
    include("model/model.jl")
    include("solvers/solvers.jl")
    export Model, Solvers, Util

end #module