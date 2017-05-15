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

    


end