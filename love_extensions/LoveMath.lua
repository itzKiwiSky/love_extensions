---Interpolate a value creating a wave effect
---@param low number
---@param high number
---@param time number
---@param fn function
---@return number
function love.math.wave(low, high, time, fn)
    fn = fn or function(dt) return -math.cos(dt) end
    return low + (fn(time) + 1) / 2 * (high - low)
end

---comment
---@param value number
---@param min number
---@param max number
---@return number
function love.math.bound(value, min, max)
    local lowerBound = (min ~= nil and value < min) and min or value
    return (max ~= nil and lowerBound > max) and max or lowerBound
end

---Returns the linear interpolation of two numbers if its ratio
--- is between 0 and 1
---@param a number
---@param b number
---@param t number
---@return number
function love.math.lerp(a, b, t)
    return a + (b - a) * t
end

--- Adjust the lerp function to account for deltatime, good if you want smooth values
--- based on the framerate
---@param a number
---@param b number
---@param decay number
---@return number
function love.math.lerpDT(a, b, decay)
    if math.abs(a - b) < 0.001 then return b end
    return math.lerp(a, b, 1 - decay ^ love.timer.getDelta())
end

---Makes sure that value always stays between min and max,
---by wrapping the value around.
---@param value number
---@param min number
---@param max number
---@return number
function love.math.wrap(value, min, max)
    local range = max - min + 1
    if value < min then
        value = value + range * ((min - value) / range + 1)
    end
    return min + (value - min) % range
end

---Remaps a number from one range to another
---@param value number
---@param inMin number
---@param inMax number
---@param outMin number
---@param outMax number
---@return number
function love.math.map(value, inMin, inMax, outMin, outMax)
    return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin
end

---Calculate the distance between two points
---@param x1 number
---@param x2 number
---@param y1 number
---@param y2 number
---@return number
function love.math.dist(x1, x2, y1, y2) return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) end

---calculate the square root distance of the two points
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return number
function love.math.sqrtdist(x1, y1, x2, y2)
    return (x2 - x1) ^ 2 + (y2 - y1) ^ 2
end

return love.math
