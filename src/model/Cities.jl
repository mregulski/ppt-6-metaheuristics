import Base.show, Base.zero
using Tsp.Util
type City
    id::Int
    x::Float32
    y::Float32
    tabu::Int
    chunk_x::Int
    chunk_y::Int
end

"""
A rectangular region of a 2D space

       |
    y1 |....+------+
       |    |      |
       |    |      |
    y0 |....+------+
       |    :      :
    (0,0)------------
            x0     x1

x, y - chunk coordinates on the grid
"""
type Chunk
    x0::Float32
    x1::Float32
    y0::Float32
    y1::Float32
    x::Int
    y::Int
    cities::Array{City}
end

type Grid
    cities::Array{City} # city data
    chunks::Array{Chunk, 2} # grid sectors
    distances::Array{Float32, 2} # doesn't make sense :O
end


type GridGeometry
    sw::Tuple{Float32,Float32}
    ne::Tuple{Float32,Float32}
    area::Float32
    width::Float32
    height::Float32
end

# =================================
#   CITY
# =================================

City(id::Int, x::Float32, y::Float32) = City(id, x, y, 0, -1, -1)

zero(::Type{City}) = City(0, NaN, NaN, -1, -1, -1)

function Base.show(stream::IO, city::City)
    show(stream, "City($(city.id) @ ($(city.x), $(city.y)), in chunk ($(city.chunk_x), $(city.chunk_y)))")
end

"""
    distance(City, City)
Calculate euclidean distance between 2 cities.
"""
@inline function distance(a::City, b::City)
    sqrt((a.x-b.x)^2 + (a.y-b.y)^2)
end

@inline function distance(a::City, b::City, grid::Grid)
    sqrt((a.x-b.x)^2 + (a.y-b.y)^2)
    # super slow for some reason
    # if a.id > b.id
    #     if grid.distances[a.id, b.id] == 0 && a.id != b.id
    #         grid.distances[a.id, b.id] = sqrt((a.x-b.x)^2 + (a.y-b.y)^2)
    #     end
    #     return grid.distances[a.id, b.id]
    # else
    #     if grid.distances[b.id, a.id] == 0 && a.id != b.id
    #         grid.distances[b.id, a.id] = sqrt((a.x-b.x)^2 + (a.y-b.y)^2)
    #     end
    #     return grid.distances[b.id, a.id]
    # end
end

"Make the city tabu until round n"
@inline function make_tabu(city::City, n::Int)
    city.tabu = n
end

"Load cities from file"
function load_cities(file::IOStream)
    size = file
    lines = eachline(file)
    size = parse(Int, first(lines))
    cities = Array(City, size)
    timeLimit = -1
    for line in lines
        data = split(line)
        if length(data) == 1
            timeLimit = parse(Int, data[1])
        else
            id = parse(Int, data[1])
            cities[id] = City(
                id,
                parse(Float32, data[2]),
                parse(Float32, data[3])
            )
        end
    end
    return cities, timeLimit
end

function load_cities(file::String)
    open(file) do f
        load_cities(f)
    end
end

function random_cities(n::Int, xs, ys)
    cities = Array(City, n)
    for i in 1:n
        cities[i] = City(i, Float32(rand(xs)), Float32(rand(ys)))
    end
    return cities
end

function random_cities(n::Int, filename::String, xs, ys)
    open(filename, "w") do f
        println(f, n)
        for i in 1:n
            c = City(i, Float32(rand(xs)), Float32(rand(ys)))
            println(f, "$(c.id) $(c.x) $(c.y)")
        end
    end
end

# =================================
#   CHUNK
# =================================

zero(::Type{Chunk}) = Chunk(NaN,NaN,NaN,NaN,-1,-1, zeros(City, 0))
Chunk(x0::Float32, x1::Float32, y0::Float32, y1::Float32, x::Int, y::Int) = Chunk(x0, x1, y0, y1, x, y, [])

Base.in(city::City, chunk::Chunk) = chunk.x0 <= city.x < chunk.x1 && chunk.y0 <= city.y < chunk.y1

function Base.show(io::IO, chunk::Chunk)
    show(io, "Chunk([$(chunk.x), $(chunk.y)] @ (($(chunk.x0), $(chunk.y0)),($(chunk.x1), $(chunk.y1))), $(length(chunk.cities)) cities)")
end

# =================================
#   GRID
# =================================

zero(::Type{Grid}) = Grid(zeros(City, 0), zeros(Chunk, (0,0)), zeros(Float32, (0,0)))

Grid(cities::Array{City}, chunks::Array{Chunk, 2}) = Grid(cities, chunks, zeros(Float32, (0,0)))

function Base.show(io::IO, grid::Grid)
    if length(grid.chunks) > 0
        x0 = grid.chunks[1].x0
        y0 = grid.chunks[1].y0
        x1 = grid.chunks[end].x1
        y1 = grid.chunks[end].y1
        show(io, "Grid((($x0, $y0), ($x1, $y1)), $(length(grid.cities)) cities, $(length(grid.chunks)) chunks)")
    else
        show(io, "Grid(<empty>)")
    end
end

"""
    make_grid(Array{City})
Place cities in chunks based on cooridnates
"""
function make_grid(cities::Array{City})
    grid_size = floor(Int, length(cities)^(1/5))
    xmin, xmax = map(v->v[1], find_extremes(map(c->c.x, cities)))
    ymin, ymax = map(v->v[1], find_extremes(map(c->c.y, cities)))
    xsteps = linspace(xmin-1, xmax+1, grid_size+1)
    ysteps = linspace(ymin-1, ymax+1, grid_size+1)
    chunks = Array(Chunk, (grid_size, grid_size))
    grid = Grid(cities, chunks)
    for yi in 1:length(ysteps)-1, xi in 1:length(xsteps)-1
        @inbounds grid.chunks[xi, yi] = Chunk(xsteps[xi], xsteps[xi+1], ysteps[yi], ysteps[yi+1], xi, yi)
    end
    # println("[make_grid] Created $(length(chunks)) chunks")
    _populate_chunks!(chunks, cities)
    # println("[make_grid] Chunks populated")
    if length(cities) < 100 # precalculate ditances for low number of cities.
        grid.distances = _calculate_distances(cities)
    end
    return grid, GridGeometry((xmin, ymin), (xmax, ymax))
end

function GridGeometry(sw::Tuple{Float32,Float32}, ne::Tuple{Float32,Float32})
    width = ne[1]-sw[1]
    height = ne[2]-sw[2]
    area = width * height
    GridGeometry(sw, ne, area, width, height)
end

function print_chunk_density(grid::Grid)
    for i in 1:length(grid.chunks[:, 1])
           for j in 1:length(grid.chunks[:,1])
               chunk = grid.chunks[i,j]
               area = (chunk.x1-chunk.x0)*(chunk.y1-chunk.y0)
               @printf("%8.5f | ",length(chunk.cities)/area)
           end
           println("\n",repeat("-",length(grid.chunks[:,1])*11-1))
       end
end

function _calculate_distances(cities)
    distances = spzeros(length(cities), length(cities))
    ctr = 0
    for i in 1:length(cities), j in 1:i
        # print("\r\33[2K$ctr distances done")
        @inbounds distances[i, j] = distance(cities[i], cities[j])
        ctr += 1
    end
    return distances
end

"""
Assign cities to sectors they are in
"""
function _populate_chunks!(chunks, cities)
    ctr = 1
    interval = 0.01 * length(cities)
    for city in cities, chunk in chunks
        if city in chunk
            push!(chunk.cities, city)
            city.chunk_x = chunk.x
            city.chunk_y = chunk.y
        end
        ctr += 1
    end
end
