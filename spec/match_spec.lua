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
        assert.is_nil(m.match_root( {}, {x=2}))
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
        assert.is_nil(m.match_root( {x=1,y=3}, {x=1,y=2}))
    end)
    it("does not match shallow tables with missing same elements (all pattern elements are required)", function()
        assert.is_nil(m.match_root( {x=1,y=2}, {x=1}))
    end)
    it("matches boolean elements", function()
        assert.is.truthy(m.match_root( {[false]=false}, {[false]=false,x=1}))
        assert.is.truthy(m.match_root( {[false]=true}, {[false]=true}))
        assert.is.truthy(m.match_root( {[true]=true}, {[true]=true}))
        assert.is.truthy(m.match_root( {[true]=false}, {[true]=false}))
        -- returns false when matching false. Only nil is a bad match
        assert.is.equal(false, m.match_root( false, false))
        assert.is.truthy(m.match_root( true, true))
        assert.is_nil(m.match_root( {[false]=false}, {[false]=true}))
    end)
    describe("can match by type using one of the type predicates", function()
        it("matches numbers", function()
            local pattern = {x=m.is_number}
            assert.is.truthy(m.match_root(pattern, {x=3})) 
            assert.is_nil(m.match_root(pattern, {x="abc"})) 
        end)
        it("matches strings", function()
            local pattern = {x=m.is_string}
            assert.is.truthy(m.match_root(pattern, {x="abc"})) 
            assert.is_nil(m.match_root(pattern, {x=3})) 
        end)
        it("matches booleans", function()
            local pattern = {x=m.is_boolean}
            assert.is.truthy(m.match_root(pattern, {x=true})) 
            assert.is.same({x=false}, m.match_root(pattern, {x=false})) 
            assert.is_nil(m.match_root(pattern, {x="abc"})) 
        end)
        it("matches functions", function()
            local pattern = {x=m.is_function}
            assert.is.truthy(m.match_root(pattern, {x=function() end})) 
            assert.is_nil(m.match_root(pattern, {x=3})) 
        end)
        it("matches tables", function()
            local pattern = {x=m.is_table}
            assert.is.truthy(m.match_root(pattern, {x={y=8}})) 
            assert.is_nil(m.match_root(pattern, {x=3})) 
        end)
        it("matches arrays", function()
            local pattern = {x=m.is_array}
            assert.is.truthy(m.match_root(pattern, {x={"a"}})) 
            assert.is_nil(m.match_root(pattern, {x=3})) 
        end)
    end)
    it("can match tables by identity rather than by value", function()
        local unique = {x=1}
        local pattern = m.id(unique)
        assert.is_nil(m.match_root(pattern, {x=1}))
        assert.is.equal(unique, m.match_root(pattern, unique))
    end)
    it("does not match if a custom match function returns nil", function()
        local pattern = {x=function(element) return element == 2 or nil end}
        assert.is_nil(m.match_root(pattern, {x=3})) 
    end)
    it("matches string patterns with like using a regex", function()
        local pattern = {x=m.is_like("%d+")}
        assert.is_nil(m.match_root(pattern, {x=3})) 
        assert.is_nil(m.match_root(pattern, {x="abc"})) 
        assert.is_same({x="123"}, m.match_root(pattern, {x="123"})) 
        assert.is_same({x="123abc"}, m.match_root(pattern, {x="123abc"})) 
        local pattern = {x=m.is_like("^%d+$")}
        assert.is_nil(m.match_root(pattern, {x="123abc"})) 
    end)
    it("matches either value from a list", function()
        local pattern = {x=1, y=m.either(3,2)}
        assert.is.same({x=1,y=2}, m.match_root(pattern, {x=1,y=2})) 
        assert.is.same({x=1,y=3}, m.match_root(pattern, {x=1,y=3})) 
        assert.is_nil(m.match_root(pattern, {x=1,y=5})) 
    end)
    it("matches either value from a list, complex case with recursive match", function()
        local pattern = {x=1, y=m.either({z="a"},2)}
        assert.is.same({x=1,y={z="a"}}, m.match_root(pattern, {x=1,y={z="a"}})) 
        assert.is.same({x=1,y=2}, m.match_root(pattern, {x=1,y=2})) 
        assert.is_nil(m.match_root(pattern, {x=1,y={z="b"}})) 
    end)
    it("matches for optional values", function()
        local pattern = {x=1, y=m.optional}
        assert.is.same({x=1}, m.match_root(pattern, {x=1})) 
        assert.is.same({x=1,y=2}, m.match_root(pattern, {x=1,y=2})) 
    end)
    it("matches and fills in the blanks with default values", function()
        local pattern = {x=1, y=m.default_value(5)}
        assert.is.same({x=1,y=5}, m.match_root(pattern, {x=1})) 
        assert.is.same({x=1,y=2}, m.match_root(pattern, {x=1,y=2})) 
    end)
    it("matches if a custom match function returns a value other than nil", function()
        local pattern = {x=function(element) return element == 2 end}
        assert.is.truthy(m.match_root(pattern, {x=2})) 

        local pattern = {x=function(element) return element == 2 and true end}
        assert.is.same({x=true}, m.match_root(pattern, {x=2})) 

        local pattern = {x=function(element) return element == 2 and false end}
        assert.is.same({x=false}, m.match_root(pattern, {x=2})) 
    end)
    it("matches with special matchers", function()
        assert.is.same({x = 5}, m.match_root( {x=m.value}, {x=5,y=2}))
        assert.is_nil(m.match_root( {x=m.value,y=1}, {x=1,y=2}))
        assert.is_nil(m.match_root( {x=m.value}, {y=2}))
    end)
    it("matches elements two-level (any level) deep", function()
        assert.is.same({a={b=1}}, m.match_root({a={b=1}}, {a={b=1}}))
        assert.is.same({a={b=1}}, m.match_root({a={b=1}}, {a={b=1},x=5}))
        assert.is.same({a={b=1},x=5}, m.match_root({a={b=1},x=5}, {a={b=1},x=5}))
        assert.is_nil(m.match_root({a={b=2}}, {a={b=1}}))
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
        assert.is_nil(m.match({1,2,m.nothing},{1,2,3}))

        assert.is.same({x=1,y=2}, m.match({x=m.value,y=m.value,m.nothing},{x=1,y=2}))
        assert.is.same({x=1,y=2}, m.match({x=m.value,[m.key]=2,m.nothing},{x=1,y=2}))
        assert.is_nil(m.match({x=1,y=2,m.nothing},{x=1,y=2,z=3}))
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
            assert.is_nil(matched)
            assert.is.same({}, captures)
        end)
        it("uses table match for previously captured variables", function()
            local matched, captures = m.match({m.var(1),m.var(2),m.var(1)},
                                                {{1,2},{5},{1,2}})
            assert.is.truthy(matched)
            assert.is.same({{1,2},{5}}, captures)

            local matched, captures = m.match({m.var(1),m.var(2),m.var(1)},
                                                {{1,2},{5},{1,3}})
            assert.is_nil(matched)
            assert.is.same({}, captures)
        end)
        it("finds an element in an array returning its index in a variable", function()
            local Index = m.var'index'

            assert.is.truthy(m.match({[Index] = "b"}, {"a", "b", "c"}))

            assert.is.equal(2, Index())
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
        it("fails to find when there are no matches", function()
            local z = m.find({z=m.var(1)}, {{a=8,x=3,y=4}})
            assert.is_nil(z)
        end)
        it("can find and return multiple matched variables for convenience of extraction", function()
            local y, x = m.find({x=m.var(2), y=m.var(1)}, {{a=8,x=3,y=4}})
            assert.is.equal(4, y)
            assert.is.equal(3, x)
        end)
        it("can find and return a table of matched variables for convenience of extraction", function()
            local vars = m.find({x=m.var'x', y=m.var'y'}, {{a=8,x=3,y=4}})
            assert.is.equal(4, vars.y)
            assert.is.equal(3, vars.x)
        end)
    end)
end)

describe("matcher", function()
    local function is_even(x) return x % 2 == 0 end

    local X, A, B, Even = m.var'x', m.var'a', m.var'b', m.var('even', is_even)
    local unique_object = {}
    local matcher = m.matcher{
        { 1,                "one" },
        { {"matched"},     m.matched_value },
        { "unique",     m.as_is(unique_object) },
        { {even = Even}, Even },
        { {x=X},            X},
        { {sum={a=m.var'a',b=m.var'b'}},  function(captures) return captures.a + captures.b end },
        { {sum={m.var(1),m.var(2)}},      function(captures) return captures[1] + captures[2] end },
        { {v={A, B}},        {p=A, q=B}},
        { {v={a=A, b=B}},        {pp=A, qq={b=B}, {[A]=B}}},
        { m.value,          "catch-all value" },
    }
    it("applies matched value transform", function()
        assert.is.same({"matched"}, matcher({"matched"}))
    end)
    it("leaves matched result as_is", function()
        assert.is.equal(unique_object, matcher("unique"))
    end)
    it("applies variable bound value transformation", function()
        assert.is.equal(3, matcher({x=3}))
    end)
    it("matches and captures conditional variables (variables with a predicate)", function()
        assert.is.equal("catch-all value", matcher({even=3}))
        assert.is_nil(Even())
        assert.is.equal(4, matcher({even=4}))
        assert.is.equal(4, Even())
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
    it("should be able to test identitiy equality for tables", function()
        local unique = {x=1}
        local matcher = m.matcher{
            { m.id(unique), true }
        }
        assert.is_nil(matcher({x=1}))
        assert.is.truthy(matcher(unique))
    end)
    pending("Don't know how to test this: should ignore metamethods", function()
        local matcher = m.matcher{
            { 1, "one" }
        }
        local target = {
            x = {1}
        }
        local mt = {
            __index = function(t,k) return 0 end,
            __newindex = function(t,k,v) return 1 end
        }
        setmetatable(target, mt)
        assert.is_nil(matcher(target))
    end)

    it("errors out when trying to apply transform with unbounded variable with equally-named variable in match (two variable instances with same name)", function()
        local matcher = m.matcher{
            { {x=m.var'x'}, m.var'x' }
        }
        assert.is.error(function() matcher({x=3}) end, 
            "Possibly trying to apply an unbound variable with same name as bound variable 'x': Make sure to use the same instance of var in the match and its transform (#1)")
    end)
end)
