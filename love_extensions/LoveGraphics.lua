local bit = require 'bit'

---@alias love.AtlasAsset string|love.Texture

---@---@alias love.QuadLoadMode
---| "hash"
---| "array"

---@alias love.GradientDirection
---| "vertical"
---| "horizontal"

---@alias love.ColorTable table<number>

local function processQuadGroup(mode, image, sparrow)
    mode = mode or "array"
    local quads = {}

    if mode == "array" then
        for i = 1, #sparrow.frames, 1 do
            local Quad = love.graphics.newQuad(
                sparrow.frames[i].frame.x,
                sparrow.frames[i].frame.y,
                sparrow.frames[i].frame.w,
                sparrow.frames[i].frame.h,
                image
            )

            table.insert(quads, Quad)
        end
    elseif mode == "hash" then
        for key, obj in pairs(sparrow.frames) do
            if obj.trimmed then
                quads[key:gsub("%.[^.]+$", "")] = {
                    quad = love.graphics.newQuad(
                        obj.frame.x,
                        obj.frame.y,
                        obj.frame.w,
                        obj.frame.h,
                        image
                    ),
                    sw = obj.sourceSize.w,
                    sh = obj.sourceSize.h,
                    w = obj.spriteSourceSize.w,
                    h = obj.spriteSourceSize.h,
                }
            else
                quads[key:gsub("%.[^.]+$", "")] = love.graphics.newQuad(
                    obj.frame.x,
                    obj.frame.y,
                    obj.frame.w,
                    obj.frame.h,
                    image
                )
            end
        end
    else
        error(("There is no mode named '%s'"):format(mode))
    end

    return quads
end

---Load a sprite sheet as image and the json map and returns the image and the quad as selected mode
---@param mode love.QuadLoadMode
---@param filename string
---@return love.Image
---@return table<love.Quad>
function love.graphics.newQuadFromImage(mode, filename)
    mode = mode or "array"
    local image = love.graphics.newImage(filename .. ".png")
    local jsonData = love.filesystem.read(filename .. ".json")
    local sparrow = json.decode(jsonData)

    local quads = processQuadGroup(mode, image, sparrow)
    return image, quads
end

---Get quads from filename
---@param image love.Drawable
---@param jsonData string
---@param mode love.QuadLoadMode
function love.graphics.getQuads(image, jsonData, mode)
    mode = mode or "array"
    local sparrow = json.decode(jsonData)

    local quads = processQuadGroup(mode, image, sparrow) -- discards the image data --
    return quads
end

---Get all quads by splitting a spritesheet
---@param atlas love.AtlasAsset
---@param splitX number
---@param splitY number
---@return love.Drawable, table<love.Quad>
function love.graphics.getQuadsFromAtlas(atlas, splitX, splitY)
    local image

    if type(atlas) == "string" then
        image = love.graphics.newImage(atlas)
    elseif atlas:type() == "Image" then
        image = atlas
    end

    splitX, splitY = splitX or image:getWidth(), splitY or image:getHeight()
    local quads = {}

    local frameWidth = image:getWidth() / splitX
    local frameHeight = image:getHeight() / splitY

    for y = 0, splitY - 1, 1 do
        for x = 0, splitX - 1, 1 do
            local quad = love.graphics.newQuad(
                x * frameWidth,
                y * frameHeight,
                math.floor(image:getWidth() / splitX),
                math.floor(image:getHeight() / splitY),
                image
            )

            table.insert(quads, quad)
        end
    end

    return image, quads
end

---Create a new gradient object
---@param dir love.GradientDirection
---@param colors table<love.ColorTable>
---@return love.Mesh
function love.graphics.newGradient(dir, colors)
    -- Check for direction
    local isHorizontal = true
    if dir == "vertical" then
        isHorizontal = false
    elseif dir ~= "horizontal" then
        error("bad argument #1 to 'gradient' (invalid value)", 2)
    end

    -- Check for colors
    local colorLen = #colors
    if colorLen < 2 then
        error("color list is less than two", 2)
    end

    -- Generate mesh
    local meshData = {}
    if isHorizontal then
        for i = 1, colorLen do
            local color = colors[i]
            local x = (i - 1) / (colorLen - 1)

            meshData[#meshData + 1] = { x, 1, x, 1, color[1], color[2], color[3], color[4] or 1 }
            meshData[#meshData + 1] = { x, 0, x, 0, color[1], color[2], color[3], color[4] or 1 }
        end
    else
        for i = 1, colorLen do
            local color = colors[i]
            local y = (i - 1) / (colorLen - 1)

            meshData[#meshData + 1] = { 0, y, 0, y, color[1], color[2], color[3], color[4] or 1 }
            meshData[#meshData + 1] = { 1, y, 1, y, color[1], color[2], color[3], color[4] or 1 }
        end
    end

    -- Resulting Mesh has 1x1 image size
    return love.graphics.newMesh(meshData, "strip", "static")
end

---Release a table of userdata
---@param tbl any
function love.graphics.release(tbl)
    local function releaseRecursive(tbl)
        for key, value in pairs(tbl) do
            if type(value) == "table" then
                releaseRecursive(value)
            else
                if type(value) == "userdata" and value.release then
                    value:release()
                end
            end
        end
    end

    releaseRecursive(tbl)
end

local _setColor = love.graphics.setColor

local function hexToRGBA(hex, format)
    format = format or "rgba"

    local byte3 = bit.band(bit.rshift(hex, 24), 0xFF) / 255 -- highest byte
    local byte2 = bit.band(bit.rshift(hex, 16), 0xFF) / 255
    local byte1 = bit.band(bit.rshift(hex, 8), 0xFF) / 255
    local byte0 = bit.band(hex, 0xFF) / 255 -- lowest byte

    if format == "rgba" then
        return { byte3, byte2, byte1, byte0 }
    elseif format == "argb" then
        return { byte2, byte1, byte0, byte3 }
    end

    error("Invalid color format: " .. tostring(format), 3)
end


---Set the default byte order used for packed ints.
---@param format "rgba"|"argb"
function love.graphics.setColorFormat(format)
    if format ~= "rgba" and format ~= "argb" then
        error("Invalid color format: " .. tostring(format), 2)
    end
    defaultFormat = format
end

---@return "rgba"|"argb" format
function love.graphics.getColorFormat()
    return defaultFormat
end

---Set the drawing color. Accepts 0-1 channels, a 0-1 table or a packed int.
---@overload fun(r: number, g: number, b: number, a?: number)
---@overload fun(color: number[])
---@overload fun(color: integer, format?: "rgba"|"argb")
function love.graphics.setColor(a, b, c, d)
    local t = type(a)

    if t == "table" then
        -- standard: { r, g, b [, a] }
        return original(a)
    elseif t == "number" and (b == nil or type(b) == "string") then
        -- a single number is a packed int, `b` is an optional format override
        return original(hexToRGBA(a, b or defaultFormat))
    end

    -- standard: r, g, b [, a]
    return original(a, b, c, d)
end

return love.graphics
