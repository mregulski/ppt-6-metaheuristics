for (mac, lvl) in ((:debug, Debug.DEBUG),
                  (:info, Debug.INFO),
                  (:warn, Debug.WARN),
                  (:error, Debug.ERROR))
    @eval macro $mac(msg)
        if !isdefined(:level)
            level = Debug.OFF
        end
        if level >= $lvl
            return :(Expr(:call, Debug.log, [$lvl, msg]...))
        end
        return :()
    end
end