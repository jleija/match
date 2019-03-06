local m = require("match")

describe("match", function()
    it("matches simple values", function()
        assert.is.equal(5, m.match_root(5, 5))
    end)
    it("matches simple values", function()
        assert.is.equal(5, m.match_root( m.value, 5))
    end)
    it("matches empty tables", function()
        assert.is.same({}, m.match_root({}, {}))
    end)
    it("does not matches a non-empty table and a table with content", function()
        assert.is.falsy(m.match_root( {}, {x=2}))
    end)
    it("matches shallow tables with some same elements", function()
        assert.is.same({x = 1}, m.match_root( {x=1}, {x=1,y=2}))
    end)
    it("matches shallow arrays with some same elements", function()
        assert.is.same({"a","b"}, m.match_root( {m.value,"b"}, {"a","b","c"}))
        assert.is.same({"a","b"}, m.match_root( {m.value,m.value}, {"a","b","c"}))
    end)
    it("matches all possible shallow tables with some same elements", function()
        assert.is.same({x = 1, y = 2}, m.match_root( {x=1,y=2}, {x=1,y=2}))
    end)
    it("does not match shallow tables with some different values", function()
        assert.is.falsy(m.match_root( {x=1,y=3}, {x=1,y=2}))
    end)
    it("does not match shallow tables with missing same elements (all pattern elements are required)", function()
        assert.is.falsy(m.match_root( {x=1,y=2}, {x=1}))
    end)
    it("matches with special matchers", function()
        assert.is.same({x = 5}, m.match_root( {x=m.value}, {x=5,y=2}))
        assert.is.falsy(m.match_root( {x=m.value,y=1}, {x=1,y=2}))
        assert.is.falsy(m.match_root( {x=m.value}, {y=2}))
    end)
    it("matches elements two-level (any level) deep", function()
        assert.is.same({a={b=1}}, m.match_root({a={b=1}}, {a={b=1}}))
        assert.is.same({a={b=1}}, m.match_root({a={b=1}}, {a={b=1},x=5}))
        assert.is.same({a={b=1},x=5}, m.match_root({a={b=1},x=5}, {a={b=1},x=5}))
        assert.is.falsy(m.match_root({a={b=2}}, {a={b=1}}))
        assert.is.same({a={b=1},c={d=2}}, m.match_root({a={b=1},c={d=2}}, {a={b=1},c={d=2}}))
    end)
    it("matches with cyclical references without stack overflow", function()
        local a = { x = 1 }
        local b = { x = 2 }
        a.next = b
        b.prev = a

        assert.is.same({x = 1}, m.match_root( {x=1}, a))
        assert.is.same({x = 2}, m.match_root( {x=2}, b))
    end)
    it("matches sub-table in nested tables", function()
        assert.is.same({x=1}, m.match( {x=1}, {a={b={x=1}}}))
        assert.is.same({x=2}, m.match({x=2}, {a={b={x=1},c={x=2}}}))
    end)
    it("matches sub-table in nested and cyclical tables", function()
        local a = { b = { x = { y = 1 } }}
        local b = { b = { x = { y = 2 } }}
        a.next = b
        b.prev = a

        assert.is.same({y=1}, m.match( {y=1}, a))
        assert.is.same({y=2}, m.match( {y=2}, a))
        assert.is.same({y=1}, m.match( {y=1}, b))
        assert.is.same({y=2}, m.match( {y=2}, b))

        local either = m.match( {y=m.value}, a)
        assert.is.truthy(either.y == 1 or either.y == 2)

        assert.is.same({x = {y = 2}}, 
                       m.match( 
                       { x = { y = function(x) return (x > 1) and x end}}, a))
    end)
    it("matches key and sub-table", function()
        local target = {a={b={x={y=1}, z={y=2}}}}
        assert.is.same({x={y=1}}, m.match( {[m.key]={y=1}}, target))
        assert.is.same({z={y=2}}, m.match( {[m.key]={y=2}}, target))
    end)
    it("matches value and tail in an array", function()
        assert.is.same({"a", {"b", "c"}}, 
                        m.match( {m.head, m.tail}, {"a", "b", "c"}))
        local target = {x={y={"a","b","c"}, z={1,2,3,4,5}}}
        assert.is.same({z={1,2,{3,4,5}}}, 
                        m.match( {[m.key]={1, m.value, m.tail}}, target))
    end)
    it("matches value and rest in an array", function()
        assert.is.same({"a", "b", "c"}, 
                        m.match( {m.head, m.rest}, {"a", "b", "c"}))
    end)
    it("matches value and rest in a table", function()
        assert.is.same({x=1, y=2, z=3},
                        m.match( {z=3, m.rest}, {x=1, y=2, z=3}))
        -- deeper
        assert.is.same({x=1, y=2, z=3},
                        m.match( {z=3, m.rest}, {a={x=1, y=2, z=3}, b={1,2}}))
    end)
    it("can do an exact/complete match with nothing extra", function()
        assert.is.same({1,2}, m.match({1,2,m.nothing},{1,2}))
        assert.is.falsy(m.match({1,2,m.nothing},{1,2,3}))

        assert.is.same({x=1,y=2}, m.match({x=m.value,y=m.value,m.nothing},{x=1,y=2}))
        assert.is.same({x=1,y=2}, m.match({x=m.value,[m.key]=2,m.nothing},{x=1,y=2}))
        assert.is.falsy(m.match({x=1,y=2,m.nothing},{x=1,y=2,z=3}))
    end)
    it("matches a structure in an array", function()
        local array = {
            {name="size", type="int", other={1,2,3}},
            {name="type", type="char", other="x"},
            {name="stats", type="struct_a", stats={
                                                mean = 45,
                                                max = 70}},
        }
        assert.is.same({name="type",type="char"},
                       m.match({name="type",type=m.value}, array))
        assert.is.same({name="stats", stats={mean=45,max=70}},
                       m.match({name=m.value, [m.key]=
                                  {mean=m.value,max=m.value}}, array))
        assert.is.same({mean=45},m.match({mean=m.value}, array))
        assert.is.same({name="type",other="x"},
                                m.match( {name=m.value,other="x"}, array))
    end)
    describe("match_all", function()
        it("can return all matches", function()
            assert.is.same({{x=5,y=2},{x=5,y=3}}, m.match_all( {x=5,y=m.value},
                                                        {{x=5,y=2},{x=5,y=3}}))
            assert.is.same({{y=2},{y=3}}, m.match_all( {y=m.value}, 
                                                        {{x=5,y=2},{x=5,y=3}}))
            assert.is.same(5, m.match_all( m.value, 5))
            assert.is.same({{x=5,y=2},{x=5,y=3,z=4}}, m.match_all( {x=5,m.rest}, 
                                                    {{x=5,y=2},{x=5,y=3,z=4}}))
        end)
    end)
    describe("variable capture", function()
        it("captures a variable by name", function()
            local matched, captures = m.match({x=m.var'v'}, {a={3,{x=88}}})
            assert.is.truthy(matched)
            assert.is.equal(88, captures.v)
        end)
        it("captures multiple variables by name", function()
            local matched, captures = m.match({x=m.var'x',y=m.var'y'}, 
                                                {a={3,{x=88,y=77}}})
            assert.is.truthy(matched)
            assert.is.equal(88, captures.x)
            assert.is.equal(77, captures.y)
        end)
        it("captures variables by index", function()
            local matched, captures = m.match({x=m.var(1)}, {a={3,{x=88}}})
            assert.is.truthy(matched)
            assert.is.equal(88, captures[1])
        end)
        it("captures arrays of variables when matching all", function()
            local matched, captures = m.match_all({x=m.var(1),y=m.var(2)}, 
                                                {{x=1,y=2},{x=10,y=20}})
            assert.is.truthy(matched)
            assert.is.same({{1,2},{10,20}}, captures)
        end)
        it("enforces match of previously captured variables", function()
            local matched, captures = m.match({m.var(1),m.var(2),m.var(1)},
                                                {1,2,1})
            assert.is.truthy(matched)
            assert.is.same({1,2}, captures)

            local matched, captures = m.match({m.var(1),m.var(2),m.var(1)},
                                                {1,2,3})
            assert.is.falsy(matched)
            assert.is.same({}, captures)
        end)
        it("uses table match for previously captured variables", function()
            local matched, captures = m.match({m.var(1),m.var(2),m.var(1)},
                                                {{1,2},{5},{1,2}})
            assert.is.truthy(matched)
            assert.is.same({{1,2},{5}}, captures)

            local matched, captures = m.match({m.var(1),m.var(2),m.var(1)},
                                                {{1,2},{5},{1,3}})
            assert.is.falsy(matched)
            assert.is.same({}, captures)
        end)
        it("can retrieve the variables after their use (needed for pattern dispatch)", function()
            local X, Y = m.var'x', m.var'y'
            local matched, captures, vars = m.match({X, Y}, {1, 2})
            assert.is.equal('x', vars[X])
            assert.is.equal('y', vars[Y])
            assert.is.equal(1, X())
            assert.is.equal(2, Y())
        end)
        it("keeps the last variable matched value in vars when a match_all is performed", function()
            local X = m.var'x'
            local matched, captures, vars = m.match_all(X, {1, 1, 1})
            assert.is.same({1,1,1}, matched)
            assert.is.equal(1, X())

            local X = m.var'x'
            local matched, captures, vars = m.match_all(X, {1, 1, 2})
            assert.is.truthy(matched)
            assert.is.same({1,1,2}, matched)
            assert.is.equal(2, X())     -- last value
        end)
    end)
end)

describe("matcher", function()
    local X, A, B = m.var'x', m.var'a', m.var'b'
    local matcher = m.matcher{
        { 1,                "one" },
        { {"identity"},     m.iden },
        { {x=X},            X},
        { {sum={a=m.var'a',b=m.var'b'}},  function(captures) return captures.a + captures.b end },
        { {sum={m.var(1),m.var(2)}},      function(captures) return captures[1] + captures[2] end },
        { {v={A, B}},        {p=A, q=B}},
        { {v={a=A, b=B}},        {pp=A, qq={b=B}, {[A]=B}}},
        { m.value,          "catch-all value" },
    }
    it("applies identity transform", function()
        assert.is.same({"identity"}, matcher({"identity"}))
    end)
    it("applies variable bound value transformation", function()
        assert.is.equal(3, matcher({x=3}))
    end)
    it("applies matching const transform", function()
        assert.is.equal("one", matcher(1))
        assert.is.equal("catch-all value", matcher(5))
    end)
    it("applies matching custom function transform with captures", function()
        assert.is.equal(5, matcher{sum={a=2,b=3}})
        assert.is.equal(7, matcher{sum={3,4}})
    end)
    it("applies variable substitution in transform table", function()
        assert.is.same({p=2,q=3}, matcher{v={2,3}})
    end)
    it("applies multiple variable substitution (key and value) in transform table", function()
        assert.is.same({pp='x',qq={b='y'}, {x='y'}}, matcher{v={a='x',b='y'}})
    end)
    it("should not match a non-root pattern", function()
        assert.is.equal("catch-all value", matcher({y={x=1}}))

        local matcher = m.matcher{
            { {y=1}, "y1" }
        }
        assert.is_nil(matcher({x={y=1}}))
    end)
    it("should return nil when nothing is matched", function()
        local matcher = m.matcher{
            { 1, "one" }
        }
        assert.is_nil(matcher(2))
    end)

    it("errors out when trying to apply transform with unbounded variable with equally-named variable in match (two variable instances with same name)", function()
        local matcher = m.matcher{
            { {x=m.var'x'}, m.var'x' }
        }
        assert.is.error(function() matcher({x=3}) end, 
            "Possibly trying to apply an unbound variable with same name as bound variable 'x': Make sure to use the same instance of var in the match and its transform (#1)")
    end)
end)
