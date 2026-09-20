function love.math.wave(l, h, t, fn)
    fn = fn or function(time) return -math.cos(time) end
    return l + (fn(t) + 1) / 2 * (h - l)
end

return love.math
