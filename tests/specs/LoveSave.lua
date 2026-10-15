return function(lust)
    -- helpers --
    local function sample()
        return {
            v = 1,
            a = true,
            ta = { 1, 2, 3 },
            cbs = { true, { 1, 2 }, 1, "hello", key = "value", ["idx_shit"] = true },
        }
    end

    local function wipe()
        love.save.data = {}
    end

    -- remove slots de teste para não sujar o save directory --
    local function cleanup()
        love.save.removeSlot("slot1")
        love.save.removeSlot("slot1", { encryptSave = true })
        love.save.removeSlot("slot_backup", { backupSave = true })
        love.save.removeSlot("slot_enc", { encryptSave = true })
        love.save.removeSlot("slot_hash", { hashName = true })
        love.save.removeSlot("slot_other")
        wipe()
    end

    lust.describe("Test for love.save extension", function()
        lust.before(cleanup)
        lust.after(cleanup)

        lust.it("check if the extension exist", function()
            lust.expect(love.save).to.exist()
        end)

        lust.it("should all love.save functions exist", function()
            local funcs = {
                "newSaveSlot", "isSlotLoaded", "getSlot", "setSlot",
                "reloadSlot", "saveSlot", "removeSlot", "listSlots",
            }
            for _, fn in ipairs(funcs) do
                lust.expect(love.save[fn]).to.exist()
                print("\t    - " .. fn)
            end
        end)

        lust.it("should start with no slot loaded", function()
            lust.expect(love.save.isSlotLoaded()).to.equal(false)
            lust.expect(love.save.getSlot()).to_not.exist()
        end)

        lust.it("should fail to save/reload without a loaded slot", function()
            lust.expect(love.save.saveSlot()).to.equal(false)
            lust.expect(love.save.reloadSlot()).to.equal(false)
        end)

        lust.it("Initialize a new slot", function()
            wipe()
            lust.expect(love.save.newSaveSlot("slot1")).to.equal(true)
            lust.expect(love.save.isSlotLoaded()).to.equal(true)

            local name, path, config = love.save.getSlot()
            lust.expect(name).to.equal("slot1")
            lust.expect(love.filesystem.getInfo(path)).to.exist()
            lust.expect(config.encrypt).to.equal(false)
            lust.expect(config.hash).to.equal(false)
            lust.expect(config.backup).to.equal(false)
        end)

        lust.it("Simulate a save and reload it", function()
            wipe()
            love.save.newSaveSlot("slot1")

            love.save.data = sample()
            lust.expect(love.save.saveSlot()).to.equal(true)

            -- apaga da memória e recarrega do disco --
            wipe()
            lust.expect(love.save.reloadSlot()).to.equal(true)
            lust.expect(love.save.data).to.equal(sample())
        end)

        lust.it("should load existing data when opening the slot again", function()
            wipe()
            love.save.newSaveSlot("slot1")
            love.save.data = sample()
            love.save.saveSlot()

            wipe()
            lust.expect(love.save.newSaveSlot("slot1")).to.equal(true)
            lust.expect(love.save.data).to.equal(sample())
        end)

        lust.it("should save and load with encryption", function()
            wipe()
            local opts = { encryptSave = true }
            love.save.newSaveSlot("slot_enc", opts)
            love.save.data = sample()
            love.save.saveSlot()

            -- o arquivo no disco não pode ser texto legível --
            local _, path = love.save.getSlot()
            local raw = love.filesystem.read(path)
            lust.expect(raw:find("hello", 1, true)).to_not.exist()

            wipe()
            lust.expect(love.save.reloadSlot()).to.equal(true)
            lust.expect(love.save.data).to.equal(sample())
        end)

        lust.it("should hash the slot name", function()
            wipe()
            love.save.newSaveSlot("slot_hash", { hashName = true })
            local _, path, config = love.save.getSlot()
            lust.expect(config.hash).to.equal(true)
            lust.expect(path:find("slot_hash", 1, true)).to_not.exist()
            lust.expect(love.filesystem.getInfo(path)).to.exist()
        end)

        lust.it("should fail on a corrupted save without backup", function()
            wipe()
            love.save.newSaveSlot("slot1")
            local _, path = love.save.getSlot()

            love.filesystem.write(path, "{{{ not valid lua")
            lust.expect(love.save.reloadSlot()).to.equal(false)
        end)

        lust.it("should restore a corrupted save from the backup", function()
            wipe()
            local opts = { backupSave = true }
            love.save.newSaveSlot("slot_backup", opts)

            love.save.data = { v = 1 }
            love.save.saveSlot()
            love.save.data = { v = 2 }
            love.save.saveSlot() -- backup agora guarda v = 1 --

            local _, path = love.save.getSlot()
            lust.expect(love.filesystem.getInfo(path .. ".backup")).to.exist()

            -- corrompe o principal --
            love.filesystem.write(path, "{{{ not valid lua")
            wipe()
            lust.expect(love.save.reloadSlot()).to.equal(true)
            lust.expect(love.save.data.v).to.equal(1)

            -- o principal deve ter sido restaurado --
            wipe()
            lust.expect(love.save.reloadSlot()).to.equal(true)
            lust.expect(love.save.data.v).to.equal(1)
        end)

        lust.it("should switch slots with setSlot", function()
            wipe()
            love.save.newSaveSlot("slot1")
            lust.expect(love.save.setSlot("slot_other")).to.equal(true)
            local name = love.save.getSlot()
            lust.expect(name).to.equal("slot_other")
        end)

        lust.it("should list existing slots", function()
            wipe()
            love.save.newSaveSlot("slot1")
            love.save.newSaveSlot("slot_other")

            local found = {}
            for _, n in ipairs(love.save.listSlots()) do
                found[n] = true
            end
            lust.expect(found["slot1"]).to.equal(true)
            lust.expect(found["slot_other"]).to.equal(true)
        end)

        lust.it("should remove a slot", function()
            wipe()
            love.save.newSaveSlot("slot1")
            local _, path = love.save.getSlot()

            lust.expect(love.save.removeSlot()).to.equal(true)
            lust.expect(love.filesystem.getInfo(path)).to_not.exist()
            lust.expect(love.save.isSlotLoaded()).to.equal(false)
        end)
    end)
end
