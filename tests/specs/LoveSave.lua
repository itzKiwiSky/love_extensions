return function(lust)
    lust.describe("Test for love.save extension", function()
        lust.it("check if the extension exist", function()
            lust.expect(love.save).to.exist()
        end)

        lust.it("should all love.save functions exist", function()
            local funcs = { "newSaveSlot" }
            for idx, fn in ipairs(funcs) do
                lust.expect(love.save[fn]).to.exist()
            end
        end)
    end)
end
