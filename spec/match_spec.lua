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
    it("does not match shallow tables with missing same elements", function()
        assert.is.falsy(m.match_root( {x=1,y=2}, {x=1}))
    end)
    it("matches with special matchers", function()
        assert.is.same({x = 5}, m.match_root( {x=m.value}, {x=5,y=2}))
        assert.is.falsy(m.match_root( {x=m.value,y=1}, {x=1,y=2}))
        assert.is.falsy(m.match_root( {x=m.value}, {y=2}))
    end)
    it("matches two levels", function()
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
end)
