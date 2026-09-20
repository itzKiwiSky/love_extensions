require 'love_extensions'

function love.load()
    if love.arg.parseGameArguments(arg)[1] == "--test" then
        lust = require 'tests.tools.Lust'

        local tests = fsutil.scanFolder("tests/specs")

        if #tests <= 0 then
            --print("[love.Test] No tests to run")
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

function love.draw()

end

function love.update()

end
