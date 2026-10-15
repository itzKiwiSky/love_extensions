return function(lust)
    local expect = lust.expect

    -- t = tempo atual, b = valor inicial, c = variação total, d = duração --
    local B, C, D = 10, 20, 2

    local function near(a, b, eps)
        return math.abs(a - b) <= (eps or 1e-6)
    end

    local families = { "Quad", "Cubic", "Quart", "Quint", "Sine", "Expo", "Circ", "Elastic", "Back" }
    local names = { "linear" }
    for _, f in ipairs(families) do
        names[#names + 1] = "in" .. f
        names[#names + 1] = "out" .. f
        names[#names + 1] = "inOut" .. f
    end

    -- as funções Expo têm um pequeno offset (0.001) por design --
    local function tol(name)
        return name:find("Expo") and 0.05 or 1e-6
    end

    -- famílias suaves, sem overshoot --
    local smooth = { "Quad", "Cubic", "Quart", "Quint", "Sine", "Expo", "Circ" }

    local function sample(fn, steps)
        local out = {}
        for i = 0, steps do
            out[#out + 1] = fn(D * i / steps, B, C, D)
        end
        return out
    end

    lust.describe("love.ease extension", function()
        lust.it("should expose all easing functions", function()
            for _, name in ipairs(names) do
                expect(type(love.ease[name])).to.equal("function")
            end
            print("\t    - " .. #names .. " functions")
        end)

        lust.describe("endpoints", function()
            for _, name in ipairs(names) do
                lust.it(name .. " should start at b and end at b + c", function()
                    local fn = love.ease[name]
                    expect(near(fn(0, B, C, D), B, tol(name))).to.equal(true)
                    expect(near(fn(D, B, C, D), B + C, tol(name))).to.equal(true)
                end)
            end
        end)

        lust.describe("midpoint", function()
            lust.it("linear should be exactly halfway", function()
                expect(love.ease.linear(D / 2, B, C, D)).to.equal(B + C / 2)
            end)

            for _, f in ipairs(families) do
                local name = "inOut" .. f
                lust.it(name .. " should be halfway at t = d / 2", function()
                    expect(near(love.ease[name](D / 2, B, C, D), B + C / 2, tol(name))).to.equal(true)
                end)
            end
        end)

        lust.describe("shape", function()
            for _, f in ipairs(smooth) do
                lust.it("in" .. f .. " should be below linear and out" .. f .. " above it at t = d / 2", function()
                    local half = B + C / 2
                    expect(love.ease["in" .. f](D / 2, B, C, D) < half).to.equal(true)
                    expect(love.ease["out" .. f](D / 2, B, C, D) > half).to.equal(true)
                end)
            end

            lust.it("inBack should undershoot below b at the start", function()
                expect(love.ease.inBack(D * 0.2, B, C, D) < B).to.equal(true)
            end)

            lust.it("outBack should overshoot above b + c near the end", function()
                expect(love.ease.outBack(D * 0.8, B, C, D) > B + C).to.equal(true)
            end)

            lust.it("outElastic should overshoot above b + c at some point", function()
                local max = -math.huge
                for _, v in ipairs(sample(love.ease.outElastic, 200)) do
                    max = math.max(max, v)
                end
                expect(max > B + C + 0.5).to.equal(true)
            end)

            lust.it("inElastic should undershoot below b at some point", function()
                local min = math.huge
                for _, v in ipairs(sample(love.ease.inElastic, 200)) do
                    min = math.min(min, v)
                end
                expect(min < B - 0.5).to.equal(true)
            end)
        end)

        lust.describe("monotonicity", function()
            local function check(name)
                lust.it(name .. " should never decrease", function()
                    local values = sample(love.ease[name], 100)
                    for i = 2, #values do
                        -- folga de 0.01 por causa do offset das funções Expo --
                        expect(values[i] >= values[i - 1] - 0.01).to.equal(true)
                    end
                end)
            end

            check("linear")
            for _, f in ipairs(smooth) do
                check("in" .. f)
                check("out" .. f)
                check("inOut" .. f)
            end
        end)

        lust.describe("sanity", function()
            lust.it("should always return finite numbers", function()
                for _, name in ipairs(names) do
                    for _, v in ipairs(sample(love.ease[name], 50)) do
                        expect(type(v)).to.equal("number")
                        expect(v == v).to.equal(true) -- não é NaN
                        expect(v ~= math.huge and v ~= -math.huge).to.equal(true)
                    end
                end
            end)

            lust.it("should work with a negative change (c < 0)", function()
                for _, name in ipairs(names) do
                    local fn = love.ease[name]
                    expect(near(fn(0, 100, -50, 1), 100, 0.1)).to.equal(true)
                    expect(near(fn(1, 100, -50, 1), 50, 0.1)).to.equal(true)
                end
            end)
        end)

        lust.describe("optional parameters", function()
            lust.it("inBack / outBack / inOutBack with s = 0 should match the cubic versions", function()
                for i = 0, 10 do
                    local t = D * i / 10
                    expect(near(love.ease.inBack(t, B, C, D, 0), love.ease.inCubic(t, B, C, D))).to.equal(true)
                    expect(near(love.ease.outBack(t, B, C, D, 0), love.ease.outCubic(t, B, C, D))).to.equal(true)
                    expect(near(love.ease.inOutBack(t, B, C, D, 0), love.ease.inOutCubic(t, B, C, D))).to.equal(true)
                end
            end)

            lust.it("a larger s should increase the back overshoot", function()
                local low = love.ease.inBack(D * 0.2, B, C, D, 1)
                local high = love.ease.inBack(D * 0.2, B, C, D, 3)
                expect(high < low).to.equal(true)
            end)

            lust.it("elastic functions should keep their endpoints with custom amplitude and period", function()
                for _, name in ipairs({ "inElastic", "outElastic", "inOutElastic" }) do
                    local fn = love.ease[name]
                    expect(near(fn(0, B, C, D, 30, 0.5), B)).to.equal(true)
                    expect(near(fn(D, B, C, D, 30, 0.5), B + C)).to.equal(true)
                end
            end)
        end)
    end)
end
