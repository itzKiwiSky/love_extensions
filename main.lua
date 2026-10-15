require 'love_extensions'

local function testArgs()
    if love.arg.parseGameArguments(arg)[1] == "--test" then
        local fsutil = require 'libraries.FSUtil'
        local lust = require 'tests.tools.Lust'

        local tests = fsutil.scanFolder("tests/specs")

        if #tests <= 0 then
            printf("[Love.Test] : No tests to run!")
            love.event.quit()
        end

        for _, test in ipairs(tests) do
            local t = require((test:gsub("/", ".")):gsub("%.lua", ""))
            t(lust)
        end

        love.event.quit()

        return
    end
end

function love.load()
    testArgs()
end

function love.draw()

end

function love.update()

end
