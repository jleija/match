local m = require("match")

describe("match", function()
    it("matches simple values", function()
        assert.is.equal(5, m.match(5, 5))
    end)
    it("matches simple values", function()
        assert.is.equal(5, m.match(5, m.value))
    end)
    it("matches empty tables", function()
        assert.is.same({}, m.match({}, {}))
    end)
    it("does not matches a non-empty table and a table with content", function()
        assert.is.falsy(m.match({x=2}, {}))
    end)
    it("matches shallow tables with some same elements", function()
        assert.is.same({x = 1}, m.match({x=1,y=2}, {x=1}))
    end)
    it("matches shallow arrays with some same elements", function()
        assert.is.same({"a","b"}, m.match({"a","b","c"}, {m.value,"b"}))
        assert.is.same({"a","b"}, m.match({"a","b","c"}, {m.value,m.value}))
    end)
    it("matches all possible shallow tables with some same elements", function()
        assert.is.same({x = 1, y = 2}, m.match({x=1,y=2}, {x=1,y=2}))
    end)
    it("does not match shallow tables with some different values", function()
        assert.is.falsy(m.match({x=1,y=2}, {x=1,y=3}))
    end)
    it("does not match shallow tables with missing same elements", function()
        assert.is.falsy(m.match({x=1}, {x=1,y=2}))
    end)
    it("matches with special matchers", function()
        assert.is.same({x = 5}, m.match({x=5,y=2}, {x=m.value}))
        assert.is.falsy(m.match({x=1,y=2}, {x=m.value,y=1}))
        assert.is.falsy(m.match({y=2}, {x=m.value}))
    end)
    it("matches two levels", function()
        assert.is.same({a={b=1}}, m.match({a={b=1}},{a={b=1}}))
        assert.is.same({a={b=1}}, m.match({a={b=1},x=5},{a={b=1}}))
        assert.is.same({a={b=1},x=5}, m.match({a={b=1},x=5},{a={b=1},x=5}))
        assert.is.falsy(m.match({a={b=1}},{a={b=2}}))
        assert.is.same({a={b=1},c={d=2}}, m.match({a={b=1},c={d=2}},{a={b=1},c={d=2}}))
    end)
    it("matches with cyclical references without stack overflow", function()
        local a = { x = 1 }
        local b = { x = 2 }
        a.next = b
        b.prev = a

        assert.is.same({x = 1}, m.match(a, {x=1}))
        assert.is.same({x = 2}, m.match(b, {x=2}))
    end)
    it("matches sub-table in nested tables", function()
        assert.is.same({x=1}, m.match_anywhere({a={b={x=1}}}, {x=1}))
        assert.is.same({x=2}, m.match_anywhere({a={b={x=1},c={x=2}}},{x=2}))
    end)
    it("matches sub-table in nested and cyclical tables", function()
        local a = { b = { x = { y = 1 } }}
        local b = { b = { x = { y = 2 } }}
        a.next = b
        b.prev = a

        assert.is.same({y=1}, m.match_anywhere(a, {y=1}))
        assert.is.same({y=2}, m.match_anywhere(a, {y=2}))
        assert.is.same({y=1}, m.match_anywhere(b, {y=1}))
        assert.is.same({y=2}, m.match_anywhere(b, {y=2}))

        local either = m.match_anywhere(a, {y=m.value})
        assert.is.truthy(either.y == 1 or either.y == 2)

        assert.is.same({x = {y = 2}}, 
                       m.match_anywhere(a, 
                       { x = { y = function(x) return (x > 1) and x end}}))
    end)
    it("matches key and sub-table", function()
        local source = {a={b={x={y=1}, z={y=2}}}}
        assert.is.same({x={y=1}}, m.match_anywhere(source, {[m.key]={y=1}}))
        assert.is.same({z={y=2}}, m.match_anywhere(source, {[m.key]={y=2}}))
    end)
    it("matches value and rest in an array", function()
        assert.is.same({"a", {"b", "c"}}, 
                        m.match_anywhere({"a", "b", "c"}, 
                                         {m.value, m.rest}))
        local source = {x={y={"a","b","c"}, z={1,2,3,4,5}}}
        assert.is.same({z={1,2,{3,4,5}}}, 
                        m.match_anywhere(source,
                            {[m.key]={1, m.value, m.rest}}))
    end)
end)
