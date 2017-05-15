__precompile__()
module Model
    include("Cities.jl")
    export City, Chunk, Grid
    export distance, make_tabu
    export load_cities, make_grid, print_chunk_density

    include("Routes.jl")
    export Route
    export score, score!, total_distance, report, nearest_neighbour, find_nearest

end