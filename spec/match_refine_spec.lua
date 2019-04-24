local mr = require("match_refine")
local m = require("match")

describe("match-refine", function()
    it("rolls constant projections", function()
        local refiner = mr.match_refine{
            { {"a", "b"}, { { x = 1 }, { y = 2} } }
        }
        assert.is.same({ a=2, b=3, x=1, y=2 }, refiner{a=2, b=3})
    end)
    it("rolls a single projection", function()
        local function sum(set) return set.a + set.b end
        local refiner = mr.match_refine{
            { {"a", "b"}, { { x = sum } } }
        }
        assert.is.same({ a=2, b=3, x=5 }, refiner{a=2, b=3})
    end)
    it("rolls function projections", function()
        local function insert_x(set) set.x = 1 return set end
        local function insert_y(set) set.y = 2 return set end
        local refiner = mr.match_refine{
            { {"a", "b"}, { insert_x, insert_y } }
        }
        assert.is.same({ a=2, b=3, x=1, y=2 }, refiner{a=2, b=3})
    end)
    it("rolls refine projections", function()
        local function inc_a(set) set.a = set.a + 1 return set end
        local refiner = mr.match_refine{
            { {"a", "b", "c"}, {"ok"} },
            { {"a", "b"}, { { c=3 } } },
            { {a=1}, { {b=2}, mr.refine } },
            { {a=2}, { {b=2}, mr.refine, mr.refine } }
        }
        assert.is.same({a=1,b=2,c=3}, refiner{a=1})
        assert.is.same("ok", refiner{a=2})
    end)
    pending("can do fibonacci?", function()
        local function inc_a(set) set.a = set.a + 1 return set end
        local refiner = mr.match_refine{
            { 1, 1 },
            { {"n", "n_1"}, { { c=3 } } },
            { {a=1}, { {b=2}, mr.refine } },
            { {a=2}, { {b=2}, mr.refine, mr.refine } }
        }
        assert.is.same({a=1,b=2,c=3}, refiner{a=1})
        assert.is.same("ok", refiner{a=2})
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
            { {"a", "b"}, { { x = sum }, mr.refine } },
        }
        assert.is.equal( 10, refiner{a=2, b=3})
    end)
    it("can reference variables in projections", function()
        local function double_x(set) return set.x * 2 end
        local refiner = mr.match_refine{
            { {"x"}, { double_x } },
            { {"a", "b"}, { { x = mr.vars.a }, mr.refine } },
        }
        assert.is.equal( 4, refiner{a=2, b=3})
    end)
    it("allows for a default clause", function()
        local refiner = mr.match_refine{
            { {"a", "b"}, { "not this one" } },
            { m.otherwise,             { 1 } }
        }
        assert.is.same( 1, refiner{x="value x"})
    end)
    it("allows for simple matcher clauses", function()
        local refiner = mr.match_refine{
            { 1, "one" },
            { 2, "two" },
        }
        assert.is.same( "two", refiner(2))
    end)
    it("allows for a single, stand-alone, consequent function (no need for array consequent)", function()
        local function sum(set) return set.a + set.b end
        local refiner = mr.match_refine{
            { {"a", "b"}, sum },
            { {"x", "y"}, { {a=mr.vars.x, b=mr.vars.y}, sum } },
        }
        assert.is.same( 3, refiner{a=1, b=2})
        assert.is.same( 3, refiner{x=1, y=2})
    end)
end)
