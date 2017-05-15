__precompile__()
module Tsp
    module Debug
        @enum Level OFF=-1 ERROR=1 WARN LOG INFO DEBUG

        LEVEL = OFF
        export @debug, @info, @log, @warn, @error

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

    Float32 = Float64


    include("util.jl")
    include("model/model.jl")
    include("solvers/solvers.jl")
    export Model, Solvers, Util

end