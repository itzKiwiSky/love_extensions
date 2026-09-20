local jit = require 'jit'

local availableOSes = {
    ["Windows"] = "desktop",
    ["Linux"] = "desktop",
    ["OS X"] = "desktop",
    ["Android"] = "mobile",
    ["iOS"] = "mobile",
}

---@alias love.DeviceType
---| "desktop"
---| "mobile"
---| "unknown"

---@class love.GPUInfo
---@field renderer string
---@field version string
---@field vendor string
---@field device string
---@field limits table

---@class love.PowerInfo
---@field state love.PowerState
---@field percent number|nil
---@field seconds number|nil

---@class love.MemoryUsage
---@field lua number       -- used lua bytes
---@field textures number  -- texture memory bytes (GPU)
---@field total number     -- combination of both bytes
---@field images integer
---@field canvases integer
---@field fonts integer

---Return the device system based on the OS
---@return love.DeviceType
function love.system.getDeviceType()
    local os = love.system.getOS()
    if availableOSes[os] then
        return availableOSes[os]
    else
        return "unknown"
    end
end

---Check if you are in a mobile environment
---@return boolean
function love.system.isMobile()
    return love.system.getDeviceType() == "mobile"
end

---Check if you are in a desktop environment
---@return boolean
function love.system.isDesktop()
    return love.system.getDeviceType() == "desktop"
end

--- get the device processor architecture
---@return string
function love.system.getArchitecture()
    if jit and jit.arch then
        return jit.arch
    end
    return "unknown"
end

---Get the system username, returns nil if not possible do discover
---@return string|nil
function love.system.getUsername()
    return os.getenv("USERNAME") -- Windows
        or os.getenv("USER")     -- Linux / macOS
        or os.getenv("LOGNAME")  -- fallback POSIX
end

---@return love.PowerInfo
function love.system.getPower()
    local state, percent, seconds = love.system.getPowerInfo()
    return {
        state = state,
        percent = percent,
        seconds = seconds,
    }
end

--- check if the battery is charging
---@return boolean
function love.system.isCharging()
    local state = love.system.getPowerInfo()
    return state == "charging"
end

---returns true if the device running on battery mode and the power is at limit or lower
---on devices without battery it returns false
---@param threshold? number  --  default 20
---@return boolean
function love.system.isLowBattery(threshold)
    threshold = threshold or 20
    local state, percent = love.system.getPowerInfo()
    return state == "battery" and percent ~= nil and percent <= threshold
end

-- cache for each call
local _stats = {}

---@return love.MemoryUsage
function love.system.getMemoryUsage()
    local lua_bytes = collectgarbage("count") * 1024

    local textures, images, canvases, fonts = 0, 0, 0, 0
    if love.graphics and love.graphics.getStats then
        local stats = love.graphics.getStats(_stats)
        textures = stats.texturememory or 0
        images = stats.images or 0
        canvases = stats.canvases or 0
        fonts = stats.fonts or 0
    end

    return {
        lua = lua_bytes,
        textures = textures,
        total = lua_bytes + textures,
        images = images,
        canvases = canvases,
        fonts = fonts,
    }
end

---format the byte output to be more readable
---@param bytes number
---@return string
function love.system.formatBytes(bytes)
    local units = { "B", "KB", "MB", "GB", "TB" }
    local i = 1
    while bytes >= 1024 and i < #units do
        bytes = bytes / 1024
        i = i + 1
    end
    if i == 1 then
        return string.format("%d %s", bytes, units[i])
    end
    return string.format("%.2f %s", bytes, units[i])
end

---copy a text to the clipboard, returns true if sucess
---@param text string
---@return boolean
function love.system.copyToClipboard(text)
    if text == nil then
        return false
    end
    local ok = pcall(love.system.setClipboardText, tostring(text))
    return ok
end

--- returns the clipboard text or nil if fails
---@return string|nil
function love.system.pasteFromClipboard()
    local ok, text = pcall(love.system.getClipboardText)
    if ok and type(text) == "string" then
        return text
    end
    return nil
end

---Return the GPU information, only works if the window is already created and initialized
---@return love.GPUInfo|nil
function love.system.getGPUInfo()
    if not (love.graphics and love.window and love.window.isOpen()) then
        return nil
    end

    local renderer, version, vendor, device = love.graphics.getRendererInfo()
    return {
        renderer = renderer,
        version = version,
        vendor = vendor,
        device = device,
        limits = love.graphics.getSystemLimits(),
    }
end

return love.system
