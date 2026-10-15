local ext = (...):match('(.-)[^%.]+$')

local crypt = require(ext .. "include.BoxCrypt")
local utils = require(ext .. "include.LuaUtils")

local basePath = "saves"
local extension = "lovedata"
local backupSuffix = ".backup"
local loadData = load or loadstring

---@private
---@param algo love.HashFunction
---@param data string
---@return string
local function hash(algo, data)
    local d = love._version_major >= 12 and love.data.hash("string", algo, data) or love.data.hash(algo, data)
    return love.data.encode("string", "hex", d)
end

---@class love.SaveOptions
---@field encryptSave boolean
---@field hashName boolean
---@field backupSave boolean

---@class love.SaveConfig
---@field encrypt boolean
---@field hash boolean
---@field backup boolean

local decryptKey = hash("sha512", love.filesystem.getIdentity())

-- estado do slot atual --
local current = {
    name = nil, ---@type string?
    path = nil, ---@type string?
    config = nil, ---@type love.SaveConfig?
    loaded = false,
}

love.save = {
    data = {}, -- Stores all the save data --
}

-- handlers: repassam para love.saveloaded / love.saveupdated / love.saveerror --
love.handlers["saveloaded"] = function(...)
    if love.saveloaded then love.saveloaded(...) end
end
love.handlers["saveupdated"] = function(...)
    if love.saveupdated then love.saveupdated(...) end
end
love.handlers["saveerror"] = function(...)
    if love.saveerror then love.saveerror(...) end
end

local function pushError(msg)
    love.event.push("saveerror", msg)
end

---@param options love.SaveOptions?
---@return love.SaveConfig
local function buildConfig(options)
    options = options or {}
    return {
        encrypt = options.encryptSave or false,
        hash = options.hashName or false,
        backup = options.backupSave or false,
    }
end

local function getPath(saveName, config)
    local filename = config.hash and hash("sha1", saveName) or saveName
    return string.format("%s/%s.%s", basePath, filename, extension)
end

local function getBackupPath(path)
    return path .. backupSuffix
end

---@return string
local function serialize(config)
    local serialized = utils.serialize(love.save.data)
    if config.encrypt then
        return crypt(serialized, decryptKey)
    end
    return serialized
end

--- Lê um arquivo e converte para tabela. Retorna tabela ou nil, erro
---@return table|nil, string|nil
local function readSave(path, config)
    local raw = love.filesystem.read(path)
    if raw == nil then
        return nil, "The save has no content"
    end

    local str = raw
    if config.encrypt then
        str = crypt(raw, decryptKey)
    end

    local chunk, err = loadData("return " .. str)
    if not chunk then
        return nil, "Corrupted save: " .. tostring(err)
    end

    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then
        return nil, "Corrupted save: " .. tostring(result)
    end

    return result
end

local function writeFile(path, content)
    local ok, err = love.filesystem.write(path, content)
    if not ok then
        pushError("Error: could not write '" .. path .. "' (" .. tostring(err) .. ")")
        return false
    end
    return true
end

--- Cria o arquivo do slot com os dados atuais
local function createSaveFile(path, config)
    if writeFile(path, serialize(config)) then
        if config.backup then
            writeFile(getBackupPath(path), serialize(config))
        end
        love.event.push("saveupdated")
        return true
    end
    return false
end

--- Carrega o slot (com fallback para o backup se o principal estiver corrompido)
local function loadSave(name, path, config)
    if love.filesystem.getInfo(path) == nil then
        pushError("Error: Invalid save name")
        return false
    end

    local data, err = readSave(path, config)

    if data == nil and config.backup then
        local backupPath = getBackupPath(path)
        if love.filesystem.getInfo(backupPath) then
            local backupData = readSave(backupPath, config)
            if backupData then
                -- restaura o principal a partir do backup --
                writeFile(path, love.filesystem.read(backupPath))
                data = backupData
            end
        end
    end

    if data == nil then
        pushError("Error: " .. tostring(err))
        return false
    end

    love.save.data = utils.deepmerge(love.save.data, data)
    current.name = name
    current.path = path
    current.config = config
    current.loaded = true
    love.event.push("saveloaded")
    return true
end

--- Initialize a new save slot (or load it if it already exists)
---@param saveName string?
---@param options love.SaveOptions?
---@return boolean
function love.save.newSaveSlot(saveName, options)
    saveName = saveName or love.filesystem.getIdentity()
    local config = buildConfig(options)

    if love.filesystem.getInfo(basePath) == nil then
        love.filesystem.createDirectory(basePath)
    end

    local path = getPath(saveName, config)

    if love.filesystem.getInfo(path) == nil then
        if not createSaveFile(path, config) then
            return false
        end
    end

    return loadSave(saveName, path, config)
end

---@return boolean
function love.save.isSlotLoaded()
    return current.loaded
end

--- Retorna nome, caminho e config do slot atual (ou nil se nenhum carregado)
---@return string?, string?, love.SaveConfig?
function love.save.getSlot()
    if not current.loaded then return nil end
    local c = current.config
    return current.name, current.path, { encrypt = c.encrypt, hash = c.hash, backup = c.backup }
end

--- Troca para outro slot (cria se não existir)
---@param saveName string
---@param options love.SaveOptions?
---@return boolean
function love.save.setSlot(saveName, options)
    current.loaded = false
    return love.save.newSaveSlot(saveName, options)
end

--- Recarrega o slot atual do disco
---@return boolean
function love.save.reloadSlot()
    if not current.loaded then
        pushError("Error: No slot loaded")
        return false
    end
    return loadSave(current.name, current.path, current.config)
end

--- Instantly save all the data on the slot file
--- This also triggers a custom "love.saveupdated" event
---@return boolean
function love.save.saveSlot()
    if not current.loaded then
        pushError("Error: No slot loaded")
        return false
    end

    local path, config = current.path, current.config

    -- o backup guarda o estado ANTERIOR do arquivo principal --
    if config.backup and love.filesystem.getInfo(path) then
        local old = love.filesystem.read(path)
        if old then
            writeFile(getBackupPath(path), old)
        end
    end

    if not writeFile(path, serialize(config)) then
        return false
    end

    love.event.push("saveupdated")
    return true
end

--- Remove um slot (e o backup). Sem argumentos remove o slot atual.
---@param saveName string?
---@param options love.SaveOptions?
---@return boolean
function love.save.removeSlot(saveName, options)
    local path
    if saveName then
        path = getPath(saveName, buildConfig(options))
    elseif current.loaded then
        path = current.path
    else
        pushError("Error: No slot to remove")
        return false
    end

    local removed = false
    if love.filesystem.getInfo(path) then
        removed = love.filesystem.remove(path)
    end
    if love.filesystem.getInfo(getBackupPath(path)) then
        love.filesystem.remove(getBackupPath(path))
    end

    if current.path == path then
        current.loaded = false
        current.name, current.path, current.config = nil, nil, nil
    end

    return removed
end

--- Lista os arquivos de slot existentes (com hashName os nomes vêm como hash)
---@return string[]
function love.save.listSlots()
    local slots = {}
    if love.filesystem.getInfo(basePath) == nil then
        return slots
    end
    for _, file in ipairs(love.filesystem.getDirectoryItems(basePath)) do
        local name = file:match("^(.+)%." .. extension .. "$")
        if name then
            slots[#slots + 1] = name
        end
    end
    return slots
end

return love.save
