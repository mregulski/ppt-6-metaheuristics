import Base.show
import Base.zero
import Base.isless
type Route
    cities::Array{City}
    score::Float32
end

Route(cities::Array{City}) = Route(copy(cities), score(cities))
Route(route::Route) = Route(copy(route.cities), route.score)

Base.length(r::Route) = length(r.cities)
Base.getindex(r::Route, idx) = getindex(r.cities, idx)
Base.setindex!(r::Route, val, idx) = setindex!(r.cities, val, idx)
Base.endof(r::Route) = endof(r.cities)

zero(::Type{Route}) = Route(zeros(City, 0), -1)

function Base.show(io::IO, route::Route)
    print(io, "Route(")
    print(io, map(city->city.id, route.cities))
    print(io, " Total length: $(route.score))")
end

function score(cities::Array{City})
    total = 0.0f0
    for i in 0:length(cities) - 1
        total += distance(cities[i % length(cities) + 1], cities[(i + 1) % length(cities) + 1])
    end
    return total
end

function score(cities::Array{City}, grid::Grid)
    total = 0.0f0
    for i in 0:length(cities) - 1
        total += distance(cities[i % length(cities) + 1], cities[(i + 1) % length(cities) + 1], grid)
    end
    return total
end

function score!(route::Route)
    route.score = score(route.cities)
    route.score
end

function score!(route::Route, grid::Grid)
    route.score = score(route.cities, grid)
    route.score
end

isless(a::Route, b::Route) = a.score < b.score
function total_distance(route::Route)
    total = 0.0f0
    for i in 0:length(route) - 1
        total += distance(route[i % length(route) + 1], route[(i + 1) % length(route) + 1])
    end
    return total
end

function report(route::Route)
    print("<")
    for city in route[1:end-1]
        print("$(city.id),")
    end
    print("$(route[end].id)>\n")
    println("Total length: $(total_distance(route))")
end

