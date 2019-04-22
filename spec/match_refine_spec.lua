local mr = require("match_refine")

describe("match-refine", function()
        -- TODO: CONTINUE HERE 2019/04/20: implement match-refine
    it("rolls a single projection", function()
        local function sum(set) return set.a + set.b end
        local refiner = mr.match_refine{
            { {"a", "b"}, { { x = sum } } }
        }
        assert.is.same({ a=2, b=3, x=5 }, refiner{a=2, b=3})
    end)
    it("does multiple projections and last value is returned", function()
        local function sum(set) return set.a + set.b end
        local function double_x(set) return set.x * 2 end
        local refiner = mr.match_refine{
            { {"a", "b"}, { { x = sum }, double_x } }
        }
        assert.is.equal( 10, refiner{a=2, b=3})
    end)
    it("does multiple projections and last value is returned", function()
        local function sum(set) return set.a + set.b end
        local function double_x(set) return set.x * 2 end
        local refiner = mr.match_refine{
            { {"x"}, { double_x } },
            { {"a", "b"}, { { x = sum }, mr.refine{} } },
        }
        assert.is.equal( 10, refiner{a=2, b=3})
    end)
end)
