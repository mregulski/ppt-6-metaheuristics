import Base.show
import Base.zero
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

"""
    nearest_neighbour(cities)
Finds a TSP route through cities using nearest-neighbour approach
"""
function nearest_neighbour(grid::Grid)
    # route = Array(City, length(cities) + 1)
    route::Array{City} = [grid.cities[1]]
    visited = zeros(Bool, length(grid.cities))
    visited[1] = true
    while length(route) != length(grid.cities)
        current = route[end]
        nearest = find_nearest(current, grid, visited)
        push!(route, nearest)
        visited[nearest.id] = true
    end
    push!(route, grid.cities[1])
    return Route(route)
end

function nearest_neighbour(cities::Array{City})
    # route = Array(City, length(cities) + 1)
    route::Array{City} = [cities[1]]
    visited = zeros(Bool, length(cities))
    visited[1] = true
    while length(route) != length(cities)
        current = route[end]
        nearest = find_nearest(current, cities, visited)
        push!(route, nearest)
        visited[nearest.id] = true
    end
    push!(route, cities[1])
    return Route(route)
end

"""
    nearest_neighbour_2(cities)
Nearest neighbour, look at both ends at the same
NOTE: apparently worse initial distance than regular NN
"""
function nearest_neighbour_2(grid::Grid)
    route::Array{City} = Array(City, length(grid.cities) + 1)
    route[1] = route[end] = grid.cities[1]
    visited = zeros(Bool, length(grid.cities))
    visited[1] = true
    head = tail = grid.cities[1]
    head_idx = 1
    tail_idx = length(grid.cities)+1
    # while length(route) < length(cities)
    while head_idx < tail_idx - length(grid.cities) % 2
        head_idx += 1
        tail_idx -= 1
        println(route)
        println("head: $head_idx, tail: $tail_idx")
        next = find_nearest(head, grid, visited)
        prev = find_nearest(tail, grid, visited)
        if next == prev
            println("conflict")
            if score(route[head_idx-1], next) < score(route[tail_idx+1], next)
                # the found point is closer to "head" than the "tail"
                route[head_idx] = next
                visited[next.id] = true
                prev = find_nearest(tail, grid, visited) # new head is second nearest
            else # found point is closer to the tail
                route[tail_idx] = prev
                visited[prev.id] = true
                next = find_nearest(head, grid, visited)
            end
        end
        println("Setting $head_idx to $next")
        route[head_idx] = next
        visited[next.id] = true
        if head_idx < tail_idx
            println("Setting $tail_idx to $prev")
            route[tail_idx] = prev
            visited[prev.id] = true
        end

    end
    return Route(route)
end

function find_nearest(current::City, grid::Grid, visited::Array{Bool})
    nearest = 0
    for id in 1:length(grid.cities)
        city = grid.cities[id]
        if visited[city.id]
            continue
        end
        if nearest == 0
            nearest = city
        elseif distance(current, city, grid) < distance(current, nearest, grid)
            nearest = city
        end
    end
    return nearest
end

function find_nearest(current::City, cities::Array{City}, visited::Array{Bool})
    nearest = 0
    for id in 1:length(cities)
        city = cities[id]
        if visited[city.id]
            continue
        end
        if nearest == 0
            nearest = city
        elseif distance(current, city) < distance(current, nearest)
            nearest = city
        end
    end
    return nearest
end