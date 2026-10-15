return function(lust)
    local expect = lust.expect

    -- troca temporariamente tbl[key] por value enquanto body roda --
    local function stub(tbl, key, value, body)
        local old = tbl[key]
        tbl[key] = value
        local ok, err = pcall(body)
        tbl[key] = old
        if not ok then error(err, 0) end
    end

    local function withOS(name, body)
        stub(love.system, "getOS", function() return name end, body)
    end

    local function withPower(state, percent, seconds, body)
        stub(love.system, "getPowerInfo", function() return state, percent, seconds end, body)
    end

    local function withEnv(env, body)
        stub(os, "getenv", function(key) return env[key] end, body)
    end

    lust.describe("love.system extension", function()
        lust.it("should expose all extension functions", function()
            local funcs = {
                "getDeviceType", "isMobile", "isDesktop", "getArchitecture", "getUsername",
                "getPower", "isCharging", "isLowBattery", "getMemoryUsage", "formatBytes",
                "copyToClipboard", "pasteFromClipboard", "getGPUInfo",
            }
            for _, fn in ipairs(funcs) do
                expect(type(love.system[fn])).to.equal("function")
                print("\t    - " .. fn)
            end
        end)

        lust.describe("device type", function()
            lust.it("should map desktop operating systems", function()
                for _, name in ipairs({ "Windows", "Linux", "OS X" }) do
                    withOS(name, function()
                        expect(love.system.getDeviceType()).to.equal("desktop")
                        expect(love.system.isDesktop()).to.equal(true)
                        expect(love.system.isMobile()).to.equal(false)
                    end)
                end
            end)

            lust.it("should map mobile operating systems", function()
                for _, name in ipairs({ "Android", "iOS" }) do
                    withOS(name, function()
                        expect(love.system.getDeviceType()).to.equal("mobile")
                        expect(love.system.isMobile()).to.equal(true)
                        expect(love.system.isDesktop()).to.equal(false)
                    end)
                end
            end)

            lust.it("should return unknown for other operating systems", function()
                withOS("Other", function()
                    expect(love.system.getDeviceType()).to.equal("unknown")
                    expect(love.system.isMobile()).to.equal(false)
                    expect(love.system.isDesktop()).to.equal(false)
                end)
            end)

            lust.it("should return a valid type on the real system", function()
                local t = love.system.getDeviceType()
                expect(t == "desktop" or t == "mobile" or t == "unknown").to.equal(true)
            end)
        end)

        lust.describe("getArchitecture", function()
            lust.it("should return the luajit architecture", function()
                local arch = love.system.getArchitecture()
                expect(type(arch)).to.equal("string")
                expect(arch).to.equal(require("jit").arch)
            end)
        end)

        lust.describe("getUsername", function()
            lust.it("should prefer USERNAME, then USER, then LOGNAME", function()
                withEnv({ USERNAME = "win", USER = "unix", LOGNAME = "posix" }, function()
                    expect(love.system.getUsername()).to.equal("win")
                end)
                withEnv({ USER = "unix", LOGNAME = "posix" }, function()
                    expect(love.system.getUsername()).to.equal("unix")
                end)
                withEnv({ LOGNAME = "posix" }, function()
                    expect(love.system.getUsername()).to.equal("posix")
                end)
            end)

            lust.it("should return nil when nothing is available", function()
                withEnv({}, function()
                    expect(love.system.getUsername()).to_not.exist()
                end)
            end)
        end)

        lust.describe("power", function()
            lust.it("getPower should wrap getPowerInfo in a table", function()
                withPower("battery", 55, 3600, function()
                    local p = love.system.getPower()
                    expect(p.state).to.equal("battery")
                    expect(p.percent).to.equal(55)
                    expect(p.seconds).to.equal(3600)
                end)
            end)

            lust.it("getPower should keep nil values", function()
                withPower("nobattery", nil, nil, function()
                    local p = love.system.getPower()
                    expect(p.state).to.equal("nobattery")
                    expect(p.percent).to_not.exist()
                    expect(p.seconds).to_not.exist()
                end)
            end)

            lust.it("isCharging should only be true on the charging state", function()
                withPower("charging", 50, nil, function()
                    expect(love.system.isCharging()).to.equal(true)
                end)
                for _, state in ipairs({ "battery", "charged", "nobattery", "unknown" }) do
                    withPower(state, 50, nil, function()
                        expect(love.system.isCharging()).to.equal(false)
                    end)
                end
            end)

            lust.it("isLowBattery should use a default threshold of 20", function()
                withPower("battery", 10, nil, function()
                    expect(love.system.isLowBattery()).to.equal(true)
                end)
                withPower("battery", 20, nil, function()
                    expect(love.system.isLowBattery()).to.equal(true)
                end)
                withPower("battery", 21, nil, function()
                    expect(love.system.isLowBattery()).to.equal(false)
                end)
            end)

            lust.it("isLowBattery should accept a custom threshold", function()
                withPower("battery", 40, nil, function()
                    expect(love.system.isLowBattery(50)).to.equal(true)
                    expect(love.system.isLowBattery(30)).to.equal(false)
                end)
            end)

            lust.it("isLowBattery should be false when not on battery or without a percent", function()
                withPower("charging", 5, nil, function()
                    expect(love.system.isLowBattery()).to.equal(false)
                end)
                withPower("nobattery", nil, nil, function()
                    expect(love.system.isLowBattery()).to.equal(false)
                end)
                withPower("battery", nil, nil, function()
                    expect(love.system.isLowBattery()).to.equal(false)
                end)
            end)
        end)

        lust.describe("getMemoryUsage", function()
            lust.it("should report lua and total memory", function()
                local m = love.system.getMemoryUsage()
                expect(m.lua > 0).to.equal(true)
                expect(m.total).to.equal(m.lua + m.textures)
                for _, key in ipairs({ "textures", "images", "canvases", "fonts" }) do
                    expect(type(m[key])).to.equal("number")
                end
            end)

            lust.it("should fall back to zeros without love.graphics.getStats", function()
                stub(love.graphics, "getStats", nil, function()
                    local m = love.system.getMemoryUsage()
                    expect(m.textures).to.equal(0)
                    expect(m.images).to.equal(0)
                    expect(m.canvases).to.equal(0)
                    expect(m.fonts).to.equal(0)
                    expect(m.total).to.equal(m.lua)
                end)
            end)
        end)

        lust.describe("formatBytes", function()
            lust.it("should print plain bytes without decimals", function()
                expect(love.system.formatBytes(0)).to.equal("0 B")
                expect(love.system.formatBytes(512)).to.equal("512 B")
                expect(love.system.formatBytes(1023)).to.equal("1023 B")
            end)

            lust.it("should convert to larger units with two decimals", function()
                expect(love.system.formatBytes(1024)).to.equal("1.00 KB")
                expect(love.system.formatBytes(1536)).to.equal("1.50 KB")
                expect(love.system.formatBytes(1024 ^ 2)).to.equal("1.00 MB")
                expect(love.system.formatBytes(5 * 1024 ^ 2)).to.equal("5.00 MB")
                expect(love.system.formatBytes(1024 ^ 3)).to.equal("1.00 GB")
                expect(love.system.formatBytes(1024 ^ 4)).to.equal("1.00 TB")
            end)

            lust.it("should cap at TB", function()
                expect(love.system.formatBytes(1024 ^ 5)).to.equal("1024.00 TB")
            end)
        end)

        lust.describe("clipboard", function()
            lust.it("copyToClipboard should return false for nil without touching the clipboard", function()
                local called = false
                stub(love.system, "setClipboardText", function() called = true end, function()
                    expect(love.system.copyToClipboard(nil)).to.equal(false)
                end)
                expect(called).to.equal(false)
            end)

            lust.it("copyToClipboard should convert the value to a string", function()
                local received
                stub(love.system, "setClipboardText", function(text) received = text end, function()
                    expect(love.system.copyToClipboard(123)).to.equal(true)
                end)
                expect(received).to.equal("123")
            end)

            lust.it("copyToClipboard should return false when setClipboardText errors", function()
                stub(love.system, "setClipboardText", function() error("no clipboard") end, function()
                    expect(love.system.copyToClipboard("x")).to.equal(false)
                end)
            end)

            lust.it("pasteFromClipboard should return the clipboard text", function()
                stub(love.system, "getClipboardText", function() return "abc" end, function()
                    expect(love.system.pasteFromClipboard()).to.equal("abc")
                end)
            end)

            lust.it("pasteFromClipboard should return nil on errors or non-string values", function()
                stub(love.system, "getClipboardText", function() error("no clipboard") end, function()
                    expect(love.system.pasteFromClipboard()).to_not.exist()
                end)
                stub(love.system, "getClipboardText", function() return nil end, function()
                    expect(love.system.pasteFromClipboard()).to_not.exist()
                end)
                stub(love.system, "getClipboardText", function() return 123 end, function()
                    expect(love.system.pasteFromClipboard()).to_not.exist()
                end)
            end)

            lust.it("should roundtrip through the real clipboard", function()
                local original = love.system.getClipboardText()
                expect(love.system.copyToClipboard("love.system spec")).to.equal(true)
                expect(love.system.pasteFromClipboard()).to.equal("love.system spec")
                love.system.setClipboardText(original or "")
            end)
        end)

        lust.describe("getGPUInfo", function()
            lust.it("should return nil when there is no open window", function()
                stub(love.window, "isOpen", function() return false end, function()
                    expect(love.system.getGPUInfo()).to_not.exist()
                end)
            end)

            lust.it("should return the renderer info when the window is open", function()
                if not love.window.isOpen() then
                    expect(love.system.getGPUInfo()).to_not.exist()
                    return
                end

                local info = love.system.getGPUInfo()
                expect(type(info.renderer)).to.equal("string")
                expect(type(info.version)).to.equal("string")
                expect(type(info.vendor)).to.equal("string")
                expect(type(info.device)).to.equal("string")
                expect(type(info.limits)).to.equal("table")
            end)
        end)
    end)
end
