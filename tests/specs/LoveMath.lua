return function(lust)
    local expect = lust.expect

    local function near(a, b, eps)
        return math.abs(a - b) <= (eps or 1e-9)
    end

    -- troca temporariamente tbl[key] por value enquanto body roda --
    local function stub(tbl, key, value, body)
        local old = tbl[key]
        tbl[key] = value
        local ok, err = pcall(body)
        tbl[key] = old
        if not ok then error(err, 0) end
    end

    lust.describe("love.math extension", function()
        lust.it("should expose all functions", function()
            local funcs = { "wave", "bound", "lerp", "lerpDT", "wrap", "map", "dist", "sqrtdist" }
            for _, fn in ipairs(funcs) do
                expect(type(love.math[fn])).to.equal("function")
                print("\t    - " .. fn)
            end
        end)

        lust.describe("wave", function()
            lust.it("should start at low and peak at high with the default function", function()
                expect(near(love.math.wave(0, 10, 0), 0)).to.equal(true)
                expect(near(love.math.wave(0, 10, math.pi), 10)).to.equal(true)
                expect(near(love.math.wave(0, 10, math.pi / 2), 5)).to.equal(true)
            end)

            lust.it("should respect a non-zero low", function()
                expect(near(love.math.wave(5, 15, 0), 5)).to.equal(true)
                expect(near(love.math.wave(5, 15, math.pi), 15)).to.equal(true)
            end)

            lust.it("should accept a custom function", function()
                expect(love.math.wave(0, 10, 0, function() return 1 end)).to.equal(10)
                expect(love.math.wave(0, 10, 0, function() return -1 end)).to.equal(0)
            end)

            lust.it("should always stay between low and high", function()
                for i = 0, 100 do
                    local v = love.math.wave(2, 8, i * 0.37)
                    expect(v >= 2 - 1e-9 and v <= 8 + 1e-9).to.equal(true)
                end
            end)
        end)

        lust.describe("bound", function()
            lust.it("should keep values already inside", function()
                expect(love.math.bound(5, 0, 10)).to.equal(5)
            end)

            lust.it("should clamp to min and max", function()
                expect(love.math.bound(-5, 0, 10)).to.equal(0)
                expect(love.math.bound(15, 0, 10)).to.equal(10)
            end)

            lust.it("should ignore a nil min or max", function()
                expect(love.math.bound(-5, nil, 10)).to.equal(-5)
                expect(love.math.bound(15, nil, 10)).to.equal(10)
                expect(love.math.bound(15, 0, nil)).to.equal(15)
                expect(love.math.bound(-1, 0, nil)).to.equal(0)
                expect(love.math.bound(7, nil, nil)).to.equal(7)
            end)
        end)

        lust.describe("lerp", function()
            lust.it("should return the endpoints", function()
                expect(love.math.lerp(0, 10, 0)).to.equal(0)
                expect(love.math.lerp(0, 10, 1)).to.equal(10)
            end)

            lust.it("should interpolate in between", function()
                expect(love.math.lerp(0, 10, 0.5)).to.equal(5)
                expect(love.math.lerp(10, 0, 0.25)).to.equal(7.5)
                expect(love.math.lerp(-10, 10, 0.75)).to.equal(5)
            end)
        end)

        lust.describe("lerpDT", function()
            lust.it("should snap to b when values are almost equal", function()
                expect(love.math.lerpDT(9.9995, 10, 0.1)).to.equal(10)
            end)

            lust.it("should not move when delta time is zero", function()
                stub(love.timer, "getDelta", function() return 0 end, function()
                    expect(love.math.lerpDT(0, 10, 0.1)).to.equal(0)
                end)
            end)

            lust.it("should be framerate based: 1 - decay^dt", function()
                -- 1 - 0.25^0.5 = 0.5, then lerp(0, 10, 0.5) = 5
                stub(love.timer, "getDelta", function() return 0.5 end, function()
                    expect(near(love.math.lerpDT(0, 10, 0.25), 5)).to.equal(true)
                end)
            end)
        end)

        lust.describe("wrap", function()
            lust.it("should keep values already inside the range", function()
                expect(love.math.wrap(0, 0, 9)).to.equal(0)
                expect(love.math.wrap(5, 0, 9)).to.equal(5)
                expect(love.math.wrap(9, 0, 9)).to.equal(9)
            end)

            lust.it("should wrap values above max", function()
                expect(love.math.wrap(10, 0, 9)).to.equal(0)
                expect(love.math.wrap(12, 0, 9)).to.equal(2)
                expect(love.math.wrap(25, 0, 9)).to.equal(5)
            end)

            lust.it("should wrap values below min", function()
                expect(love.math.wrap(-1, 0, 9)).to.equal(9)
                expect(love.math.wrap(-10, 0, 9)).to.equal(0)
                expect(love.math.wrap(-11, 0, 9)).to.equal(9)
            end)

            lust.it("should work with a non-zero min", function()
                expect(love.math.wrap(6, 3, 5)).to.equal(3)
                expect(love.math.wrap(2, 3, 5)).to.equal(5)
                expect(love.math.wrap(1, 3, 5)).to.equal(4)
            end)
        end)

        lust.describe("map", function()
            lust.it("should remap between ranges", function()
                expect(love.math.map(5, 0, 10, 0, 100)).to.equal(50)
                expect(love.math.map(0, 0, 10, -1, 1)).to.equal(-1)
                expect(love.math.map(10, 0, 10, -1, 1)).to.equal(1)
            end)

            lust.it("should support inverted output and negative input ranges", function()
                expect(love.math.map(2.5, 0, 10, 100, 0)).to.equal(75)
                expect(love.math.map(-5, -10, 0, 0, 1)).to.equal(0.5)
            end)
        end)

        lust.describe("dist / sqrtdist", function()
            lust.it("dist should compute the euclidean distance (x1, x2, y1, y2)", function()
                expect(love.math.dist(0, 3, 0, 4)).to.equal(5)
                expect(love.math.dist(3, 0, 4, 0)).to.equal(5)
                expect(love.math.dist(1, 1, 2, 2)).to.equal(0)
            end)

            lust.it("sqrtdist should return the squared distance (x1, y1, x2, y2)", function()
                expect(love.math.sqrtdist(0, 0, 3, 4)).to.equal(25)
                expect(love.math.sqrtdist(1, 1, 1, 1)).to.equal(0)
            end)

            lust.it("dist and sqrtdist should agree for the same points", function()
                local x1, y1, x2, y2 = 2, 3, 8, 11
                local a = love.math.dist(x1, x2, y1, y2)
                local b = math.sqrt(love.math.sqrtdist(x1, y1, x2, y2))
                expect(near(a, b)).to.equal(true)
            end)
        end)
    end)
end
