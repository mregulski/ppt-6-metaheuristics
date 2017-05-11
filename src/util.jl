module Util

    export find_extremes, random_cities

    """
        find_extremes(array)
    Locate minimum and maximum in array.
    #Return value
    ((minimum, idx_of_min), (maximum, idx_of_max))
    """
    function find_extremes(arr::AbstractArray)
        min = max = arr[1]
        min_i = max_i = 1
        for i in 2:length(arr)
            if arr[i] > max
                max, max_i = arr[i], i
            elseif arr[i] < min
                min, min_i = arr[i], i
            end
        end
        return ((min, min_i), (max, max_i))
    end

    function random_cities(n::Int, filename::String, xs, ys)
        open(filename, "w") do f
            println(f, n)
            for c in random_cities(n, xs, ys)
                println(f, "$(c.id) $(c.x) $(c.y)")
            end
        end
    end

    function random_cities(n::Int, xs, ys)
        cities = Array(City, n)
        @simd for i in 1:n
            @inbounds cities[i] = City(i, Float32(rand(xs)), Float32(rand(ys)))
        end
        return cities
    end
end