return function(lust)
    local expect = lust.expect

    local function near(a, b, eps)
        return math.abs(a - b) <= (eps or 1e-3)
    end

    local function fails(fn)
        return not pcall(fn)
    end

    local function count(t)
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        return n
    end

    -- 0.1s de silêncio --
    local function makeSource(channels)
        local data = love.sound.newSoundData(800, 8000, 16, channels or 1)
        return love.audio.newSource(data)
    end

    -- mixer com a source "jump" e o canal "sfx" já registrados --
    local function newMixer(maxSources, polyphony)
        local m = love.mixer.newMixer(maxSources, polyphony)
        m:addSource("jump", makeSource(1))
        m:addChannel("sfx")
        return m
    end

    lust.describe("love.mixer extension", function()
        lust.it("should expose newMixer", function()
            expect(type(love.mixer.newMixer)).to.equal("function")
        end)

        lust.it("should expose all Mixer methods", function()
            local m = love.mixer.newMixer()
            local funcs = {
                "addSource", "getSource", "addChannel", "playChannel", "stopChannel",
                "pauseChannel", "resumeChannel", "stopAllChannels", "pauseAllChannels",
                "resumeAllChannels", "setChannelPan", "fadeTo", "update",
                "getMasterVolume", "setMasterVolume",
                "getChannelVolume", "setChannelVolume",
                "getChannelPitch", "setChannelPitch",
                "getChannelLoop", "setChannelLoop",
            }
            for _, fn in ipairs(funcs) do
                expect(type(m[fn])).to.equal("function")
                print("\t    - " .. fn)
            end
        end)

        lust.it("should create independent mixers", function()
            local a = love.mixer.newMixer()
            local b = love.mixer.newMixer()
            a:addChannel("music")
            expect(a:getChannelVolume("music")).to.equal(1)
            expect(b:getChannelVolume("music")).to_not.exist()
        end)

        lust.it("polyphony should default to false", function()
            expect(love.mixer.newMixer().polyphony).to.equal(false)
            expect(love.mixer.newMixer(32, true).polyphony).to.equal(true)
        end)

        lust.describe("source rack", function()
            lust.it("should register and get a source by tag", function()
                local m = love.mixer.newMixer()
                local src = makeSource()
                m:addSource("jump", src)
                expect(m:getSource("jump")).to.equal(src)
                expect(m:getSource("nope")).to_not.exist()
            end)

            lust.it("should generate a tag when none is given", function()
                local m = love.mixer.newMixer()
                local src = makeSource()
                m:addSource(nil, src)
                expect(m:getSource("snd_1")).to.equal(src)
            end)

            lust.it("should replace a source registered with the same tag", function()
                local m = love.mixer.newMixer()
                local a, b = makeSource(), makeSource()
                m:addSource("jump", a)
                m:addSource("jump", b)
                expect(m:getSource("jump")).to.equal(b)
            end)

            lust.it("should error when the max source count is reached", function()
                local m = love.mixer.newMixer(2)
                m:addSource("a", makeSource())
                m:addSource("b", makeSource())
                expect(fails(function() m:addSource("c", makeSource()) end)).to.equal(true)
            end)

            lust.it("should default to a limit of 32 sources", function()
                local m = love.mixer.newMixer()
                for i = 1, 32 do
                    m:addSource("s" .. i, makeSource())
                end
                expect(fails(function() m:addSource("extra", makeSource()) end)).to.equal(true)
            end)

            lust.it("dynamic mode should not limit the source count", function()
                local m = love.mixer.newMixer("dynamic")
                for i = 1, 100 do
                    m:addSource("s" .. i, makeSource())
                end
                expect(m:getSource("s100")).to.exist()
            end)
        end)

        lust.describe("channels", function()
            lust.it("should create a channel with default settings", function()
                local m = love.mixer.newMixer()
                m:addChannel("music")
                expect(m:getChannelVolume("music")).to.equal(1)
                expect(m:getChannelPitch("music")).to.equal(1)
                expect(m:getChannelLoop("music")).to.equal(false)
            end)

            lust.it("should generate a name when none is given", function()
                local m = love.mixer.newMixer()
                m:addChannel(nil)
                expect(m:getChannelVolume("chn_1")).to.equal(1)
            end)

            lust.it("adding an existing channel should not reset it", function()
                local m = love.mixer.newMixer()
                m:addChannel("music")
                m:setChannelVolume("music", 0.3)
                m:addChannel("music")
                expect(m:getChannelVolume("music")).to.equal(0.3)
            end)

            lust.it("should get and set volume, pitch and loop", function()
                local m = love.mixer.newMixer()
                m:addChannel("music")

                m:setChannelVolume("music", 0.5)
                m:setChannelPitch("music", 1.5)
                m:setChannelLoop("music", true)

                expect(m:getChannelVolume("music")).to.equal(0.5)
                expect(m:getChannelPitch("music")).to.equal(1.5)
                expect(m:getChannelLoop("music")).to.equal(true)
            end)

            lust.it("getters should return nil and setters should be ignored for unknown channels", function()
                local m = love.mixer.newMixer()
                expect(m:getChannelVolume("nope")).to_not.exist()
                expect(m:getChannelPitch("nope")).to_not.exist()
                expect(m:getChannelLoop("nope")).to_not.exist()

                m:setChannelVolume("nope", 0.5)
                m:setChannelPitch("nope", 2)
                m:setChannelLoop("nope", true)
            end)
        end)

        lust.describe("playChannel", function()
            lust.it("should ignore nil arguments", function()
                local m = newMixer()
                m:playChannel(nil, "jump")
                m:playChannel("sfx", nil)
            end)

            lust.it("should error on an unknown channel or source", function()
                local m = newMixer()
                expect(fails(function() m:playChannel("nope", "jump") end)).to.equal(true)
                expect(fails(function() m:playChannel("sfx", "nope") end)).to.equal(true)
            end)

            lust.it("should play the source on the channel", function()
                local m = newMixer()
                m:playChannel("sfx", "jump")
                expect(m._channels.sfx._sources.jump).to.equal(m:getSource("jump"))
                m:stopAllChannels()
            end)

            lust.it("should multiply the play settings by the channel settings", function()
                local m = newMixer()
                m:setChannelVolume("sfx", 0.5)
                m:setChannelPitch("sfx", 0.5)
                m:playChannel("sfx", "jump", { volume = 0.5, pitch = 2 })

                local src = m:getSource("jump")
                expect(near(src:getVolume(), 0.25)).to.equal(true)
                expect(near(src:getPitch(), 1)).to.equal(true)
                m:stopAllChannels()
            end)

            lust.it("should use the channel loop by default and allow enabling it per play", function()
                local m = newMixer()
                m:playChannel("sfx", "jump")
                expect(m:getSource("jump"):isLooping()).to.equal(false)

                m:playChannel("sfx", "jump", { loop = true })
                expect(m:getSource("jump"):isLooping()).to.equal(true)
                m:stopAllChannels()
            end)

            lust.it("should allow a play call to disable the channel loop", function()
                local m = newMixer()
                m:setChannelLoop("sfx", true)

                m:playChannel("sfx", "jump")
                expect(m:getSource("jump"):isLooping()).to.equal(true)

                m:playChannel("sfx", "jump", { loop = false })
                expect(m:getSource("jump"):isLooping()).to.equal(false)
                m:stopAllChannels()
            end)

            lust.it("polyphony should play clones that can overlap", function()
                local m = newMixer(32, true)
                local original = m:getSource("jump")

                m:playChannel("sfx", "jump")
                m:playChannel("sfx", "jump")

                local sources = m._channels.sfx._sources
                expect(count(sources)).to.equal(2)
                for _, s in pairs(sources) do
                    expect(s ~= original).to.equal(true)
                end
                m:stopAllChannels()
            end)
        end)

        lust.describe("stop / pause / resume", function()
            lust.it("stopChannel with a tag should remove only that source", function()
                local m = newMixer()
                m:addSource("coin", makeSource())
                m:playChannel("sfx", "jump")
                m:playChannel("sfx", "coin")

                m:stopChannel("sfx", "jump")
                expect(m._channels.sfx._sources.jump).to_not.exist()
                expect(m._channels.sfx._sources.coin).to.exist()
                m:stopAllChannels()
            end)

            lust.it("stopChannel without a tag should remove every source", function()
                local m = newMixer()
                m:addSource("coin", makeSource())
                m:playChannel("sfx", "jump")
                m:playChannel("sfx", "coin")

                m:stopChannel("sfx")
                expect(count(m._channels.sfx._sources)).to.equal(0)
            end)

            lust.it("stopChannel should ignore nil and unknown channels", function()
                local m = newMixer()
                m:stopChannel(nil)
                m:stopChannel("nope")
                m:stopChannel("sfx", "nope")
            end)

            lust.it("pauseChannel / resumeChannel should toggle the paused flag", function()
                local m = newMixer()
                m:playChannel("sfx", "jump")

                m:pauseChannel("sfx")
                expect(m._channels.sfx._paused).to.equal(true)

                m:resumeChannel("sfx")
                expect(m._channels.sfx._paused).to.equal(false)
                m:stopAllChannels()
            end)

            lust.it("pause / resume should ignore nil and unknown channels", function()
                local m = newMixer()
                m:pauseChannel(nil)
                m:pauseChannel("nope")
                m:resumeChannel(nil)
                m:resumeChannel("nope")
            end)

            lust.it("*AllChannels should affect every channel", function()
                local m = newMixer()
                m:addChannel("music")
                m:addSource("theme", makeSource())
                m:playChannel("sfx", "jump")
                m:playChannel("music", "theme")

                m:pauseAllChannels()
                expect(m._channels.sfx._paused).to.equal(true)
                expect(m._channels.music._paused).to.equal(true)

                m:resumeAllChannels()
                expect(m._channels.sfx._paused).to.equal(false)
                expect(m._channels.music._paused).to.equal(false)

                m:stopAllChannels()
                expect(count(m._channels.sfx._sources)).to.equal(0)
                expect(count(m._channels.music._sources)).to.equal(0)
            end)
        end)

        lust.describe("setChannelPan", function()
            lust.it("should ignore unknown channels and sources", function()
                local m = newMixer()
                m:setChannelPan("nope", "jump", 0)
                m:setChannelPan("sfx", "nope", 0)
            end)

            lust.it("should pan a relative mono source and clamp the value", function()
                local m = newMixer()
                local mono = makeSource(1)
                mono:setRelative(true)
                m:addSource("pan", mono)
                m:playChannel("sfx", "pan")

                m:setChannelPan("sfx", "pan", 0.25)
                expect(near(select(1, mono:getPosition()), 0.25)).to.equal(true)

                m:setChannelPan("sfx", "pan", 5)
                expect(near(select(1, mono:getPosition()), 1)).to.equal(true)

                m:setChannelPan("sfx", "pan", -5)
                expect(near(select(1, mono:getPosition()), -1)).to.equal(true)
                m:stopAllChannels()
            end)

            lust.it("should ignore stereo sources without erroring", function()
                local m = newMixer()
                m:addSource("st", makeSource(2))
                m:playChannel("sfx", "st")
                m:setChannelPan("sfx", "st", 0.5)
                m:stopAllChannels()
            end)

            lust.it("should ignore non-relative mono sources without erroring", function()
                local m = newMixer()
                m:playChannel("sfx", "jump") -- mono, mas sem setRelative(true)
                m:setChannelPan("sfx", "jump", 0.5)
                m:stopAllChannels()
            end)
        end)

        lust.describe("fadeTo / update", function()
            lust.it("fadeTo should ignore unknown channels", function()
                local m = newMixer()
                m:fadeTo("nope", 0, 1)
            end)

            lust.it("should fade the channel volume linearly", function()
                local m = newMixer()
                m:fadeTo("sfx", 0, 1)

                m:update(0.5)
                expect(near(m:getChannelVolume("sfx"), 0.5)).to.equal(true)

                m:update(0.25)
                expect(near(m:getChannelVolume("sfx"), 0.25)).to.equal(true)

                m:update(0.25)
                expect(near(m:getChannelVolume("sfx"), 0)).to.equal(true)
            end)

            lust.it("should finish and remove the fade at the end", function()
                local m = newMixer()
                m:fadeTo("sfx", 0.2, 1)
                expect(m._fades.sfx).to.exist()

                m:update(2)
                expect(m._fades.sfx).to_not.exist()
                expect(near(m:getChannelVolume("sfx"), 0.2)).to.equal(true)
            end)

            lust.it("should fade up from the current volume", function()
                local m = newMixer()
                m:setChannelVolume("sfx", 0.2)
                m:fadeTo("sfx", 1, 1)
                m:update(0.5)
                expect(near(m:getChannelVolume("sfx"), 0.6)).to.equal(true)
            end)

            lust.it("a new fade should replace the running one", function()
                local m = newMixer()
                m:fadeTo("sfx", 0, 10)
                m:update(1)
                m:fadeTo("sfx", 1, 1)
                m:update(1)
                expect(near(m:getChannelVolume("sfx"), 1)).to.equal(true)
            end)

            lust.it("update should apply channel volume and pitch changes to playing sources", function()
                local m = newMixer()
                m:playChannel("sfx", "jump")

                m:setChannelVolume("sfx", 0.3)
                m:setChannelPitch("sfx", 1.5)
                m:update(0)

                local src = m:getSource("jump")
                expect(near(src:getVolume(), 0.3)).to.equal(true)
                expect(near(src:getPitch(), 1.5)).to.equal(true)
                m:stopAllChannels()
            end)

            lust.it("update should keep the per-play volume and pitch", function()
                local m = newMixer()
                m:playChannel("sfx", "jump", { volume = 0.5, pitch = 2 })
                m:update(0)

                local src = m:getSource("jump")
                expect(near(src:getVolume(), 0.5)).to.equal(true)
                expect(near(src:getPitch(), 2)).to.equal(true)
                m:stopAllChannels()
            end)

            lust.it("update should remove sources that finished playing", function()
                local m = newMixer()
                m:playChannel("sfx", "jump")
                m:getSource("jump"):stop()

                m:update(0.016)
                expect(m._channels.sfx._sources.jump).to_not.exist()
            end)

            lust.it("update should keep stopped sources while the channel is paused", function()
                local m = newMixer()
                m:playChannel("sfx", "jump")
                m:pauseChannel("sfx")

                m:update(0.016)
                expect(m._channels.sfx._sources.jump).to.exist()
                m:stopAllChannels()
            end)
        end)

        lust.describe("master volume", function()
            lust.it("should read and write love.audio's volume", function()
                local m = love.mixer.newMixer()
                local old = m:getMasterVolume()

                m:setMasterVolume(0.5)
                expect(near(m:getMasterVolume(), 0.5)).to.equal(true)
                expect(near(love.audio.getVolume(), 0.5)).to.equal(true)

                m:setMasterVolume(old)
            end)
        end)
    end)
end
