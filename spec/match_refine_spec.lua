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
    it("does multiple rolling projections collecting vars with intermediate vars", function()
        local function inc(x) return 5 + x end
        local refiner = mr.match_refine{
            { 1 , { { x = inc }, { y = mr.vars.x } } },
        }
        assert.is.same( { x = 6, y = 6 }, refiner(1))
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
        assert.is.equal( "two", refiner(2))
    end)
    it("allows for a single, stand-alone, consequent function (no need for array consequent)", function()
        local function sum(set) return set.a + set.b end
        local refiner = mr.match_refine{
            { {"a", "b"}, sum },
            { {"x", "y"}, { {a=mr.vars.x, b=mr.vars.y}, sum } },
        }
        assert.is.equal( 3, refiner{a=1, b=2})
        assert.is.equal( 3, refiner{x=1, y=2})
    end)
    it("handles mixed patterns with abbreviated variables and explicit key-and-value matches", function()
        local function sum(set) return set.a + set.b end
        local function mul(set) return set.a * set.b end
        local refiner = mr.match_refine{
            { { op = "+", "a", "b"}, sum },
            { { op = "*", "a", "b"}, mul },
        }
        assert.is.equal(  7, refiner{op='+',a=3, b=4})
        assert.is.equal( 12, refiner{op='*',a=3, b=4})
    end)
    it("rolls/merges tables returned by function projections into ongoing set", function()
        local function roll_x(set) return { x = 1} end
        local function roll_y(set) return { y = 2} end
        local refiner = mr.match_refine{
            { { "a", "b"}, { roll_x, roll_y } },
            { { "z" }, { roll_x, {a=1}, roll_y } },
        }
        assert.is.same( {a=1,b=2,x=1,y=2}, refiner{a=1,b=2})
        assert.is.same( {a=1,z=2,x=1,y=2}, refiner{z=2})
    end)
    it("can use table variables with nested tables", function()
        local refiner = mr.match_refine{
            { {"a", "b"}, { { x = mr.vars.a, y = mr.vars.b.c.d } } }
        }
        assert.is.same( {a=1, b={c={d=2}}, x=1,y=2}, refiner{a=1, b={c={d=2}}} )
    end)
    it("fails when promised/expected subkeys path does not exist in bound variable", function()
        local refiner = mr.match_refine{
            { {"a", "b"}, { { x = mr.vars.a, y = mr.vars.b.c.d } } }
        }
        assert.is.error(function() refiner{a=1, b={c={e=2}}} end, 
            "Variable b does not have expected path/subkeys .c.d failed at expected subkey d")
    end)
    it("fails when trying to realize/bind/coerce with undefined var", function()
        local refiner = mr.match_refine{
            { {"a", "b"}, { { x = mr.vars.a, y = mr.vars.k } } }
        }
        assert.is.error(function() refiner{a=1, b=2} end, "No value matched for variable k")
    end)
    it("is ok to return nil in a consequent", function()
        local count = 0
        local function call_me() count = count + 1 end
        local count_too = 0
        local function call_me_too() count_too = count_too + 1 end
        local refiner = mr.match_refine{
            { "here", call_me },    -- call_me returns nil. Still ends matching 
            { "here", call_me_too },-- this should not be tested
            { m.otherwise, 4 }
        }
        assert.is_nil(refiner("here"))
        assert.is.equal(1, count)
        assert.is.equal(0, count_too)
    end)
    it("tests a single predicate", function()
        local refiner = mr.match_refine{
            { m.is_array, "array" },
            { m.is_string, function(x) return #x end },
            { m.otherwise, "other" }
        }
        assert.is.equal("array", refiner{1,2,3} )
        assert.is.equal(3, refiner("abc") )
        assert.is.equal("other", refiner(2))
    end)
    pending("passes original set to a function consequent, not just the matching elements of it. Maybe this behavior is not desired(?)", function()
        local got_c
        local function get_c(set) got_c = set.c return set end
        local original = { a=1, b=2, c=3 }
        local refiner = mr.match_refine{
            { { "a", "b" }, get_c }
        }
        refiner(original)
        assert.is.equal(3, got_c)
    end)
    it("passes original set a list consequent, not just the matching elements of it", function()
        local got_c
        local function get_c(set) got_c = set.c return set end
        local original = { a=1, b=2, c=3 }
        local refiner = mr.match_refine{
            { { "a", "b" }, { get_c, { z=mr.vars.c } } }
        }
        local res = refiner(original)
        assert.is.equal(3, got_c)
        assert.is.same({a=1, b=2, c=3, z=3}, res)
    end)
    it("displays errors with template name and rule number, when available", function()
        local function failed_op(set) return set.a + set.x end
        local refiner = mr.match_refine{
            name = "template_a",
            { { "a", "b" }, { failed_op } }
        }
        local _, err = pcall(function() refiner{a=1, b=0} end)
        assert.is.truthy(err:match("match_refine template_a, rule 1, refine 1.*attempt to perform arithmetic on field 'x' %(a nil value%)"))
    end)
    it("displays errors with template name and rule name, when available", function()
        local function failed_op(set) return set.a + set.x end
        local function ok_fn() return {} end
        local refiner = mr.match_refine{
            name = "template_a",
            { { "a", "b" }, { ok_fn, failed_op }, name = "rule_x" }
        }
        local _, err = pcall(function() refiner{a=1, b=0} end)
        assert.is.truthy(err:match("match_refine template_a, rule rule_x, refine 2.*attempt to perform arithmetic on field 'x' %(a nil value%)"))
    end)
    it("displays errors with full trace in nested match-refines", function()
        local function failed_op(set) return set.a + set.x end
        local function ok_fn() return {} end
        local inner_refiner = mr.match_refine{
            name = "template_inner",
            { { "z" }, {}, name = "unmatched_inner" },
            { { "a", "b" }, { ok_fn, failed_op }, name = "rule_ab" },
            { m.otherwise, print }
        }
        local outer_refiner = mr.match_refine{
            name = "template_outer",
            { { "c" }, { ok_fn, inner_refiner }, name = "rule_c" },
            { m.otherwise, print }
        }
        local res, err = pcall(function() outer_refiner{a=1, b=0, c=1} end)
        assert.is.truthy(err:match("match_refine template_outer, rule rule_c, refine 2.*match_refine template_inner, rule rule_ab, refine 2.*attempt to perform arithmetic on field 'x' %(a nil value%)"))
    end)
    pending("displays refine 1 when the refines consequent is a single function", function()
    end)
end)
