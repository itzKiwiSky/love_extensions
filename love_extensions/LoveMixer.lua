--- love.mixer
---
--- A small channel-based audio mixer built on top of `love.audio`.
---
--- Concepts:
---   * **Source rack**: audio sources registered under a string tag
---     (see `Mixer:addSource`). Sources are loaded once and reused.
---   * **Channel**: a named group (e.g. "music", "sfx", "voice") with its own
---     volume, pitch and loop settings. Everything played through a channel
---     inherits those settings.
---   * **Polyphony**: when enabled, every `playChannel` call plays a *clone*
---     of the source, so the same sound can overlap with itself.
---
--- Typical usage:
--- ```lua
--- local mixer = love.mixer.newMixer(64, true)
--- mixer:addSource("jump", love.audio.newSource("jump.wav", "static"))
--- mixer:addSource("theme", love.audio.newSource("theme.ogg", "stream"))
--- mixer:addChannel("sfx")
--- mixer:addChannel("music")
---
--- mixer:playChannel("music", "theme", { loop = true })
--- mixer:playChannel("sfx", "jump")
---
--- function love.update(dt)
---     mixer:update(dt) -- required for fades and for cleaning finished sources
--- end
--- ```
love.mixer = {}

-----------------------------------------------------------------------------------
-- MixerChannel
-----------------------------------------------------------------------------------

---A named group of playing sources sharing volume, pitch and loop settings.
---
---Channels are created through `Mixer:addChannel` and are not meant to be
---instantiated directly by the user. Fields prefixed with `_` are internal.
---@class love.MixerChannel
---@field volume number Channel volume multiplier (1 = full volume). Applied to every source playing on the channel.
---@field pitch number Channel pitch multiplier (1 = normal pitch). Applied to every source playing on the channel.
---@field loop boolean Default looping behavior for sources played on this channel (can be overridden per play call).
---@field _sources table<string, love.Source> Sources currently playing (or paused) on this channel, indexed by tag (or by a unique key in polyphony mode).
---@field _paused boolean Whether the channel is currently paused. Paused sources are not removed by `Mixer:update`.
local MixerChannel = {}
MixerChannel.__index = MixerChannel

---Create a new channel with default settings (volume 1, pitch 1, no loop).
---@return love.MixerChannel
function MixerChannel.new()
    local self = setmetatable({}, MixerChannel)
    self.volume = 1
    self.pitch = 1
    self.loop = false
    self._sources = {}
    self._paused = false
    return self
end

-----------------------------------------------------------------------------------
-- Mixer
-----------------------------------------------------------------------------------

---A mixer instance. Holds the source rack, the channels and the active fades.
---Create one with `love.mixer.newMixer`.
---@class love.Mixer
---@field _sourceAssets table<string, love.Source> Source rack: registered sources indexed by tag.
---@field _channels table<string, love.MixerChannel> Channels indexed by name.
---@field _maxSounds integer|string Maximum number of registered sources, or `"dynamic"` for no limit.
---@field _sourcesCount integer Number of sources registered so far.
---@field _channelsCount integer Number of channels created so far.
---@field _fades table<string, {from: number, to: number, duration: number, elapsed: number}> Active volume fades indexed by channel name.
---@field polyphony boolean If true, each play call plays a clone of the source so sounds can overlap.
local Mixer = {}
Mixer.__index = Mixer

---Create a new mixer instance.
---@param maxSourceCount integer|string|nil Fixed number of sources the rack accepts, `"dynamic"` for no limit, or `nil` for the default (32).
---@param polyphony boolean|nil Enable polyphony (overlapping instances of the same source). Defaults to `false`.
---@return love.Mixer
function Mixer.new(maxSourceCount, polyphony)
    local self = setmetatable({}, Mixer)
    self._sourceAssets = {}
    self._channels = {}
    self._maxSounds = maxSourceCount or 32 -- pass "dynamic" to ignore the limit
    self._sourcesCount = 0
    self._channelsCount = 0
    self.polyphony = polyphony or false
    self._fades = {} -- { channelName = { from, to, duration, elapsed } }
    return self
end

-----------------------------------------------------------------------------------
-- Source rack and channel management
-----------------------------------------------------------------------------------

---Register a source on the mixer rack.
---
---If `tag` is `nil`, a name is generated (`"snd_<n>"`). Registering a tag that
---already exists replaces the previous source.
---@param tag string|nil Name used to refer to this source afterwards.
---@param source love.Source The source to register.
---@error Raises an error if the mixer already reached its maximum source count (unless created with `"dynamic"`).
function Mixer:addSource(tag, source)
    self._sourcesCount = self._sourcesCount + 1

    if self._maxSounds ~= "dynamic" and self._sourcesCount > self._maxSounds then
        error("[Love.Mixer] : The mixer reached the max allowed source count. maxSounds = " .. self._maxSounds)
    end

    if tag == nil then
        tag = "snd_" .. self._sourcesCount
    end

    self._sourceAssets[tag] = source
end

---Get a registered source from the rack.
---@param tag string Tag the source was registered with.
---@return love.Source|nil source The source, or `nil` if no source uses that tag.
function Mixer:getSource(tag)
    return self._sourceAssets[tag]
end

---Create a new channel and attach it to the mixer.
---
---Does nothing if a channel with that name already exists. If `channelName` is
---`nil`, a name is generated (`"chn_<n>"`).
---@param channelName string|nil Name of the channel (e.g. `"music"`, `"sfx"`).
function Mixer:addChannel(channelName)
    if self._channels[channelName] then
        return
    end

    self._channelsCount = self._channelsCount + 1

    if channelName == nil then
        channelName = "chn_" .. self._channelsCount
    end

    self._channels[channelName] = MixerChannel.new()
end

-----------------------------------------------------------------------------------
-- Playback control
-----------------------------------------------------------------------------------

---Play a registered source on a channel.
---
---The final volume and pitch are the play settings multiplied by the channel's
---values. In polyphony mode a clone of the source is played (so the same sound
---can overlap itself); otherwise the source is restarted if it is already
---playing on that channel.
---
---Does nothing if `channelName` or `tag` is `nil`.
---@param channelName string Channel to play on. Must have been created with `addChannel`.
---@param tag string Tag of the source to play. Must have been registered with `addSource`.
---@param settings {volume: number|nil, pitch: number|nil, loop: boolean|nil}|nil Per-play overrides. `volume` and `pitch` default to 1; `loop` defaults to the channel's loop setting.
---@error Raises an error if the channel or the source does not exist.
function Mixer:playChannel(channelName, tag, settings)
    if channelName == nil or tag == nil then return end

    local channel = self._channels[channelName]
    if not channel then
        error("[Love.Mixer] : Channel '" .. channelName .. "' not found.")
    end

    local source = self._sourceAssets[tag]
    if not source then
        error("[Love.Mixer] : Source '" .. tag .. "' not found.")
    end

    settings         = settings or {}
    -- play volume/pitch are local to the source, they do not overwrite the channel's
    local playVolume = (settings.volume or 1) * channel.volume
    local playPitch  = (settings.pitch or 1) * channel.pitch
    local playLoop   = settings.loop or channel.loop

    if self.polyphony then
        local clone = source:clone()
        local key = tag .. "_" .. tostring(os.clock())
        channel._sources[key] = clone
        clone:setVolume(playVolume)
        clone:setPitch(playPitch)
        clone:setLooping(playLoop)
        clone:play()
    else
        -- restart the sound if it is already playing
        if channel._sources[tag] then
            channel._sources[tag]:stop()
        end
        channel._sources[tag] = source
        source:setVolume(playVolume)
        source:setPitch(playPitch)
        source:setLooping(playLoop)
        source:play()
    end
end

---Stop sources on a channel.
---
---If `tag` is given, only that source is stopped and removed from the channel.
---Otherwise every source on the channel is stopped. Unknown channels are ignored.
---
---Note: in polyphony mode sources are stored under generated keys, so stopping
---by `tag` only works in non-polyphonic mixers; omit `tag` to stop everything.
---@param channelName string Channel to stop sources on.
---@param tag string|nil Tag of a specific source to stop, or `nil` to stop all sources on the channel.
function Mixer:stopChannel(channelName, tag)
    if channelName == nil then return end

    local channel = self._channels[channelName]
    if not channel then return end

    if tag then
        local source = channel._sources[tag]
        if source then
            source:stop()
            channel._sources[tag] = nil
        end
    else
        -- stop every source on the channel
        for k, source in pairs(channel._sources) do
            source:stop()
            channel._sources[k] = nil
        end
    end
end

---Pause every source on a channel and mark the channel as paused.
---Unknown channels are ignored.
---@param channelName string
function Mixer:pauseChannel(channelName)
    if channelName == nil then return end
    local channel = self._channels[channelName]
    if not channel then return end

    for _, source in pairs(channel._sources) do
        source:pause()
    end
    channel._paused = true
end

---Resume every source on a paused channel.
---Unknown channels are ignored.
---@param channelName string
function Mixer:resumeChannel(channelName)
    if channelName == nil then return end
    local channel = self._channels[channelName]
    if not channel then return end

    for _, source in pairs(channel._sources) do
        source:play()
    end
    channel._paused = false
end

---Stop every source on every channel.
function Mixer:stopAllChannels()
    for channelName, _ in pairs(self._channels) do
        self:stopChannel(channelName)
    end
end

---Pause every channel.
function Mixer:pauseAllChannels()
    for channelName, _ in pairs(self._channels) do
        self:pauseChannel(channelName)
    end
end

---Resume every channel.
function Mixer:resumeAllChannels()
    for channelName, _ in pairs(self._channels) do
        self:resumeChannel(channelName)
    end
end

---Set the stereo panning of a source that is currently playing on a channel.
---
---`-1.0` is fully left, `0.0` is centered and `1.0` is fully right. The value
---is clamped to that range. Only works if the source is mono **and**
---`source:setRelative(true)` was called when it was created; otherwise a warning
---is printed and the call is ignored.
---@param channelName string Channel the source is playing on.
---@param tag string Tag of the source.
---@param pan number Pan value from -1.0 (left) to 1.0 (right).
function Mixer:setChannelPan(channelName, tag, pan)
    if not self._channels[channelName] then return end

    local source = self._channels[channelName]._sources[tag]
    if not source then return end

    if source:getChannelCount() ~= 1 then
        print("[Love.Mixer] : setChannelPan ignorado — source '%s' não é mono.", tag)
        return
    end

    if not source:isRelative() then
        printf("[Love.Mixer] : setChannelPan ignorado — source '%s' não tem setRelative(true).", tag)
        return
    end

    pan = math.max(-1, math.min(1, pan)) -- clamp
    source:setPosition(pan, 0, 0)
end

---Smoothly change a channel's volume over time (linear fade).
---
---The fade starts from the channel's current volume. Starting a new fade on a
---channel replaces any fade already running on it. Requires `Mixer:update(dt)`
---to be called every frame.
---@param channelName string Channel to fade. Unknown channels are ignored.
---@param targetVolume number Volume to reach at the end of the fade.
---@param duration number Fade duration in seconds.
function Mixer:fadeTo(channelName, targetVolume, duration)
    if not self._channels[channelName] then return end

    self._fades[channelName] = {
        from     = self._channels[channelName].volume,
        to       = targetVolume,
        duration = duration,
        elapsed  = 0,
    }
end

---Update the mixer. Call this once per frame in `love.update(dt)`.
---
---Does two things:
---  1. Advances active fades and applies the interpolated volume to the channels.
---  2. Re-applies each channel's volume and pitch to its sources (so changes to
---     the channel take effect immediately) and removes sources that finished
---     playing, unless the channel is paused.
---@param dt number Time since the last frame, in seconds.
function Mixer:update(dt)
    for channelName, fade in pairs(self._fades) do
        fade.elapsed = fade.elapsed + dt
        local t = math.min(fade.elapsed / fade.duration, 1)
        local vol = fade.from + (fade.to - fade.from) * t
        self:setChannelVolume(channelName, vol)

        if t >= 1 then
            self._fades[channelName] = nil
        end
    end

    for _, channel in pairs(self._channels) do
        for tag, source in pairs(channel._sources) do
            source:setVolume(channel.volume)
            source:setPitch(channel.pitch)

            -- does not force setLooping here; looping was already set in playChannel
            -- only removes sources that finished naturally (and whose channel is not paused)
            if not source:isPlaying() and not channel._paused then
                channel._sources[tag] = nil
            end
        end
    end
end

-----------------------------------------------------------------------------------
-- Getters and setters
-----------------------------------------------------------------------------------

---Get the global (master) volume, as reported by `love.audio.getVolume`.
---@return number volume Master volume from 0 to 1.
function Mixer:getMasterVolume()
    return love.audio.getVolume()
end

---Set the global (master) volume for all audio, via `love.audio.setVolume`.
---@param volume number Master volume from 0 to 1.
function Mixer:setMasterVolume(volume)
    love.audio.setVolume(volume)
end

---Get a channel's volume.
---@param name string Channel name.
---@return number|nil volume The channel volume, or `nil` if the channel does not exist.
function Mixer:getChannelVolume(name)
    if not self._channels[name] then return end
    return self._channels[name].volume
end

---Set a channel's volume. Applied to its sources on the next `update`.
---@param name string Channel name. Unknown channels are ignored.
---@param volume number Volume multiplier (1 = full volume).
function Mixer:setChannelVolume(name, volume)
    if not self._channels[name] then return end
    self._channels[name].volume = volume
end

---Get a channel's pitch.
---@param name string Channel name.
---@return number|nil pitch The channel pitch, or `nil` if the channel does not exist.
function Mixer:getChannelPitch(name)
    if not self._channels[name] then return end
    return self._channels[name].pitch
end

---Set a channel's pitch. Applied to its sources on the next `update`.
---@param name string Channel name. Unknown channels are ignored.
---@param pitch number Pitch multiplier (1 = normal pitch).
function Mixer:setChannelPitch(name, pitch)
    if not self._channels[name] then return end
    self._channels[name].pitch = pitch
end

---Get a channel's default loop setting.
---@param name string Channel name.
---@return boolean|nil loop The loop setting, or `nil` if the channel does not exist.
function Mixer:getChannelLoop(name)
    if not self._channels[name] then return end
    return self._channels[name].loop
end

---Set a channel's default loop setting. Only affects sources played afterwards.
---@param name string Channel name. Unknown channels are ignored.
---@param loop boolean Whether new sources on this channel should loop by default.
function Mixer:setChannelLoop(name, loop)
    if not self._channels[name] then return end
    self._channels[name].loop = loop
end

-----------------------------------------------------------------------------------
-- Module API
-----------------------------------------------------------------------------------

---Create a new mixer.
---@param maxSourceCount integer|string|nil Maximum number of registered sources, `"dynamic"` for no limit, or `nil` for the default (32).
---@param polyphony boolean|nil Enable polyphony (overlapping instances of the same source). Defaults to `false`.
---@return love.Mixer
function love.mixer.newMixer(maxSourceCount, polyphony)
    return Mixer.new(maxSourceCount, polyphony)
end

return love.mixer
