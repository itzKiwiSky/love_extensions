love.collision = {}

function love.collision.newShape(shape)
    local shapes = {
        ["circle"] = "circle",
        ["rectangle"] = "rectangle",
        ["point"] = { x = 0, y = 0 },
    }

    return
end

return love.collision
