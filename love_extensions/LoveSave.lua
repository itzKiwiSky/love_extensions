---@nodiscard
local ext = (...):match('(.-)[^%.]+$')

local crypt = require(ext .. "include.BoxCrypt")
local utils = require(ext .. "include.LuaUtils")
local basePath = "saves"

---@private
---@param algo love.HashFunction
---@param data string
---@return string|love.ByteData
local function hash(algo, data)
    local d = love._version_major >= 12 and love.data.hash("string", algo, data) or love.data.hash(algo, self.name)
    return love.data.encode("string", "hex", d)
end

local loadData = load or loadstring

love.save = {
    ---@private
    meta = {
        name = "",
        entries = 0,
        backup = true,
        encrypt = true,
        hashSaveName = true,
        decryptKey = hash("sha512", love.filesystem.getIdentity()), -- we use the identity as well, to make sure there is a valid decrypt key --
    },
    data = {},                                                      -- Stores all the save data ---

    -- events --
    onSaveLoaded = function() end,
    onSaveUpdated = function() end,
    onSaveError = function() end,
}

-- we create new event handlers to love --
love.handlers["saveloaded"] = function() end
love.handlers["saveupdated"] = function() end
love.handlers["saveerror"] = function() end

---@class love.SaveOptions
---@field encryptSave boolean
---@field hashName boolean
---@field backupSave boolean

--- Initialize a new save slot
---@param saveName string
---@param options love.SaveOptions
function love.save.newSaveSlot(saveName, options)
    -- if the save name is not passed, use the identity as the base name --
    saveName = saveName or love.filesystem.getIdentity()

    -- create a directory if it not exist --
    local slotDirectory = love.filesystem.getInfo(basePath)
    if slotDirectory == nil then
        love.filesystem.createDirectory(basePath)
    end

    local config = {
        encrypt = options.encryptSave or false,
        hash = options.hashName or false,
        backup = options.backupSave or false,
    }

    local extension = "lovedata"
    local filename = ""

    if config.hash then
        filename = hash("sha1", saveName)
    else
        filename = saveName
    end

    -- check if the file exist --
    local savePath = string.format("%s/%s.%s", basePath, filename, extension)
    local saveFile = love.filesystem.getInfo(savePath)
    if saveFile == nil then
        -- create a new save file and load it
        createSaveFile(savePath)
        --loadSave()
        return
    end

    -- else load it --
end

local function createSaveFile(name)
    local file = love.filesystem.newFile(name, "w")
    local serializedData = utils.serialize(love.save.data)

    local fileSucess, err = pcall(file.open, file)

    if not fileSucess then
        love.event.push("saveerror", "Error: " .. err)
        return
    end

    local finalWriteableData = ""

    if love.save.meta.encrypt then
        finalWriteableData = crypt(serializedData, love.save.meta.decryptKey)
    end

    file:write(finalWriteableData)
    file:close()

    love.event.push("saveupdated")
end

local function loadSave()

end

return love.save
