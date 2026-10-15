return function(lust)
    local expect = lust.expect

    local function near(a, b, eps)
        return math.abs(a - b) <= (eps or 1e-5)
    end

    local function fails(fn)
        return not pcall(fn)
    end

    local function makeImage(w, h)
        return love.graphics.newImage(love.image.newImageData(w, h))
    end

    local function viewport(quad)
        local x, y, w, h = quad:getViewport()
        return { x = x, y = y, w = w, h = h }
    end

    local function sameViewport(quad, x, y, w, h)
        local v = viewport(quad)
        return v.x == x and v.y == y and v.w == w and v.h == h
    end

    -- o módulo usa um `json` global; aqui trocamos por um stub que devolve o fixture --
    local function withJson(fixture, body)
        local old = _G.json
        _G.json = { decode = function() return fixture end }
        local ok, err = pcall(body)
        _G.json = old
        if not ok then error(err, 0) end
    end

    local function colorIs(r, g, b, a)
        local R, G, B, A = love.graphics.getColor()
        return near(R, r) and near(G, g) and near(B, b) and near(A, a)
    end

    local arrayFixture = {
        frames = {
            { frame = { x = 0, y = 0, w = 16, h = 16 } },
            { frame = { x = 16, y = 0, w = 16, h = 16 } },
            { frame = { x = 0, y = 16, w = 16, h = 16 } },
        },
    }

    local hashFixture = {
        frames = {
            ["idle.png"] = { frame = { x = 0, y = 0, w = 16, h = 16 } },
            ["run.png"] = {
                trimmed = true,
                frame = { x = 16, y = 0, w = 12, h = 14 },
                sourceSize = { w = 16, h = 16 },
                spriteSourceSize = { w = 12, h = 14 },
            },
        },
    }

    lust.describe("love.graphics extension", function()
        local savedColor, savedFormat

        lust.before(function()
            savedColor = { love.graphics.getColor() }
            savedFormat = love.graphics.getColorFormat and love.graphics.getColorFormat() or nil
        end)

        lust.after(function()
            if savedFormat then pcall(love.graphics.setColorFormat, savedFormat) end
            pcall(love.graphics.setColor, savedColor[1], savedColor[2], savedColor[3], savedColor[4])
        end)

        lust.it("should expose all extension functions", function()
            local funcs = {
                "newQuadFromImage", "getQuads", "getQuadsFromAtlas", "newGradient",
                "release", "setColorFormat", "getColorFormat",
            }
            for _, fn in ipairs(funcs) do
                expect(type(love.graphics[fn])).to.equal("function")
                print("\t    - " .. fn)
            end
        end)

        lust.describe("getQuads", function()
            lust.it("array mode should create one quad per frame, in order", function()
                local image = makeImage(32, 32)
                withJson(arrayFixture, function()
                    local quads = love.graphics.getQuads(image, "ignored", "array")
                    expect(#quads).to.equal(3)
                    expect(sameViewport(quads[1], 0, 0, 16, 16)).to.equal(true)
                    expect(sameViewport(quads[2], 16, 0, 16, 16)).to.equal(true)
                    expect(sameViewport(quads[3], 0, 16, 16, 16)).to.equal(true)
                end)
            end)

            lust.it("should default to array mode", function()
                local image = makeImage(32, 32)
                withJson(arrayFixture, function()
                    local quads = love.graphics.getQuads(image, "ignored")
                    expect(#quads).to.equal(3)
                end)
            end)

            lust.it("hash mode should index quads by name without the extension", function()
                local image = makeImage(32, 32)
                withJson(hashFixture, function()
                    local quads = love.graphics.getQuads(image, "ignored", "hash")
                    expect(quads["idle.png"]).to_not.exist()
                    expect(quads["run.png"]).to_not.exist()
                    expect(quads.idle:typeOf("Quad")).to.equal(true)
                    expect(sameViewport(quads.idle, 0, 0, 16, 16)).to.equal(true)
                end)
            end)

            lust.it("hash mode should keep the source size info of trimmed frames", function()
                local image = makeImage(32, 32)
                withJson(hashFixture, function()
                    local quads = love.graphics.getQuads(image, "ignored", "hash")
                    local run = quads.run
                    expect(type(run)).to.equal("table")
                    expect(run.quad:typeOf("Quad")).to.equal(true)
                    expect(sameViewport(run.quad, 16, 0, 12, 14)).to.equal(true)
                    expect(run.sw).to.equal(16)
                    expect(run.sh).to.equal(16)
                    expect(run.w).to.equal(12)
                    expect(run.h).to.equal(14)
                end)
            end)

            lust.it("should error on an unknown mode", function()
                local image = makeImage(32, 32)
                withJson(arrayFixture, function()
                    expect(fails(function()
                        love.graphics.getQuads(image, "ignored", "bogus")
                    end)).to.equal(true)
                end)
            end)
        end)

        lust.describe("newQuadFromImage", function()
            lust.it("should load <name>.png and <name>.json and return the image and quads", function()
                love.image.newImageData(32, 32):encode("png", "spec_atlas.png")
                love.filesystem.write("spec_atlas.json", "{}")

                withJson(arrayFixture, function()
                    local image, quads = love.graphics.newQuadFromImage("array", "spec_atlas")
                    expect(image:typeOf("Image")).to.equal(true)
                    expect(#quads).to.equal(3)
                end)

                love.filesystem.remove("spec_atlas.png")
                love.filesystem.remove("spec_atlas.json")
            end)
        end)

        lust.describe("getQuadsFromAtlas", function()
            lust.it("should split an image into a grid, row by row", function()
                local atlas = makeImage(64, 32)
                local image, quads = love.graphics.getQuadsFromAtlas(atlas, 4, 2)

                expect(image).to.equal(atlas)
                expect(#quads).to.equal(8)
                expect(sameViewport(quads[1], 0, 0, 16, 16)).to.equal(true)
                expect(sameViewport(quads[2], 16, 0, 16, 16)).to.equal(true)
                expect(sameViewport(quads[5], 0, 16, 16, 16)).to.equal(true)
                expect(sameViewport(quads[8], 48, 16, 16, 16)).to.equal(true)
            end)

            lust.it("should default to one quad per pixel when no split is given", function()
                local atlas = makeImage(4, 2)
                local _, quads = love.graphics.getQuadsFromAtlas(atlas)
                expect(#quads).to.equal(8)
                expect(sameViewport(quads[1], 0, 0, 1, 1)).to.equal(true)
            end)
        end)

        lust.describe("newGradient", function()
            lust.it("should return a strip mesh with two vertices per color", function()
                local mesh = love.graphics.newGradient("horizontal", { { 1, 0, 0 }, { 0, 0, 1 } })
                expect(mesh:typeOf("Mesh")).to.equal(true)
                expect(mesh:getDrawMode()).to.equal("strip")
                expect(mesh:getVertexCount()).to.equal(4)

                local three = love.graphics.newGradient("vertical", { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } })
                expect(three:getVertexCount()).to.equal(6)
            end)

            lust.it("horizontal should spread the colors along x", function()
                local mesh = love.graphics.newGradient("horizontal", { { 1, 0, 0 }, { 0, 0, 1 } })

                local x, y, _, _, r, g, b, a = mesh:getVertex(1)
                expect(x).to.equal(0)
                expect(y).to.equal(1)
                expect(r).to.equal(1)
                expect(b).to.equal(0)
                expect(a).to.equal(1) -- alpha default

                x, y, _, _, r, g, b = mesh:getVertex(3)
                expect(x).to.equal(1)
                expect(r).to.equal(0)
                expect(b).to.equal(1)
            end)

            lust.it("vertical should spread the colors along y", function()
                local mesh = love.graphics.newGradient("vertical", { { 1, 0, 0 }, { 0, 0, 1 } })

                local x, y = mesh:getVertex(2)
                expect(x).to.equal(1)
                expect(y).to.equal(0)

                x, y = mesh:getVertex(3)
                expect(x).to.equal(0)
                expect(y).to.equal(1)
            end)

            lust.it("should keep a custom alpha", function()
                local mesh = love.graphics.newGradient("horizontal", { { 1, 1, 1, 0.25 }, { 1, 1, 1, 1 } })
                local _, _, _, _, _, _, _, a = mesh:getVertex(1)
                expect(near(a, 0.25)).to.equal(true)
            end)

            lust.it("should error on an invalid direction", function()
                expect(fails(function()
                    love.graphics.newGradient("diagonal", { { 1, 0, 0 }, { 0, 0, 1 } })
                end)).to.equal(true)
            end)

            lust.it("should error with fewer than two colors", function()
                expect(fails(function()
                    love.graphics.newGradient("horizontal", { { 1, 0, 0 } })
                end)).to.equal(true)
            end)
        end)

        lust.describe("release", function()
            lust.it("should release userdata recursively", function()
                local a = makeImage(4, 4)
                local b = makeImage(4, 4)
                local tree = { a = a, nested = { deeper = { b = b } }, n = 5, s = "text" }

                love.graphics.release(tree)

                expect(fails(function() a:getWidth() end)).to.equal(true)
                expect(fails(function() b:getWidth() end)).to.equal(true)
                expect(tree.n).to.equal(5)
                expect(tree.s).to.equal("text")
            end)

            lust.it("should ignore an empty table", function()
                love.graphics.release({})
            end)
        end)

        lust.describe("setColor / color format", function()
            lust.it("should default to the rgba format", function()
                expect(love.graphics.getColorFormat()).to.equal("rgba")
            end)

            lust.it("should keep accepting r, g, b, a numbers", function()
                love.graphics.setColor(0.1, 0.2, 0.3, 0.4)
                expect(colorIs(0.1, 0.2, 0.3, 0.4)).to.equal(true)

                love.graphics.setColor(0.1, 0.2, 0.3)
                expect(colorIs(0.1, 0.2, 0.3, 1)).to.equal(true)
            end)

            lust.it("should keep accepting a table", function()
                love.graphics.setColor({ 0.5, 0.6, 0.7 })
                expect(colorIs(0.5, 0.6, 0.7, 1)).to.equal(true)

                love.graphics.setColor({ 0.5, 0.6, 0.7, 0.8 })
                expect(colorIs(0.5, 0.6, 0.7, 0.8)).to.equal(true)
            end)

            lust.it("should accept a packed rgba integer", function()
                love.graphics.setColor(0xFF0000FF)
                expect(colorIs(1, 0, 0, 1)).to.equal(true)

                love.graphics.setColor(0x00FF0080)
                expect(colorIs(0, 1, 0, 128 / 255)).to.equal(true)
            end)

            lust.it("should accept a packed argb integer when the format is overridden", function()
                love.graphics.setColor(0x80FF0000, "argb")
                expect(colorIs(1, 0, 0, 128 / 255)).to.equal(true)
                -- o override não muda o formato padrão --
                expect(love.graphics.getColorFormat()).to.equal("rgba")
            end)

            lust.it("setColorFormat should change the default format", function()
                love.graphics.setColorFormat("argb")
                expect(love.graphics.getColorFormat()).to.equal("argb")

                love.graphics.setColor(0xFFFF0000)
                expect(colorIs(1, 0, 0, 1)).to.equal(true)

                love.graphics.setColorFormat("rgba")
                love.graphics.setColor(0xFF0000FF)
                expect(colorIs(1, 0, 0, 1)).to.equal(true)
            end)

            lust.it("setColorFormat should reject an invalid format and keep the old one", function()
                love.graphics.setColorFormat("rgba")
                expect(fails(function() love.graphics.setColorFormat("bogus") end)).to.equal(true)
                expect(love.graphics.getColorFormat()).to.equal("rgba")
            end)

            lust.it("should error on an invalid format override", function()
                expect(fails(function() love.graphics.setColor(0xFF0000FF, "bogus") end)).to.equal(true)
            end)
        end)
    end)
end
