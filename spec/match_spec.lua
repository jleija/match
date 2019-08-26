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
    describe("use of value_if for custom/user predicates that might not return nil for false", function()
        local is_even = function(x) return x % 2 == 0 end
        it("won't match a false value when value_if is used. Correct use", function()
            local pattern = {x=m.value_if(is_even)}
            assert.is.truthy(m.match_root(pattern, {x=4})) 
            assert.is_nil(m.match_root(pattern, {x=3})) 
        end)
        it("will match a false value in a user predicate and pass it to the consequent. Counter example of value_if", function()
            local pattern = {x=is_even}
            assert.is.truthy(m.match_root(pattern, {x=4})) 
            assert.is.same({x=false}, m.match_root(pattern, {x=3})) 
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
    it("matches for missing values", function()
        local pattern = {x=1, y=m.missing}
        assert.is.same({x=1}, m.match_root(pattern, {x=1})) 
        assert.is_nil(m.match_root(pattern, {x=1,y=2})) 
        assert.is.same({5,8}, m.match_root({5,8}, {5,8})) 
        assert.is.same({[2]=8,[3]=9},m.match_root({m.missing,8,m.rest}, {[2]=8,[3]=9})) 
        assert.is_nil(m.match_root({5,m.missing}, {5,8})) 
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

        -- note the "or nil" return value. This is to prevent a "false" value
        -- to be taken as a successful match (only nil values in predicates
        -- count as failing match
        assert.is.same({x = {y = 2}}, 
                       m.match( 
                       { x = { y = function(x) return (x > 1) and x or nil end}}, a))
        assert.is.same({x = {y = 2}}, 
                       m.match( 
                       { x = { y = function(x) return (x > 1) and x or nil end}}, b))
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
        assert.is.same({1,2}, m.match({1,2,m.nothing_else},{1,2}))
        assert.is_nil(m.match({1,2,m.nothing_else},{1,2,3}))

        -- nothing_else is the same as nothing
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
    describe("key capture", function()
        local K = m.namespace().keys
        it("matches keys and captures their value", function()
            -- K.x is an abbreviation of x=V.x
            local matched, captures = m.match({K.x}, {a={3,{x=88}}})
            assert.is.truthy(matched)
            assert.is.equal(88, captures.x)
        end)
        it("matches keys when they are not in a table", function()
            -- K.x is an abbreviation of x=V.x
            local matched, captures = m.match(K.x, "just x")
            assert.is.truthy(matched)
            assert.is.equal("just x", captures.x)
        end)
    end)
    describe("variable capture", function()
        local V = m.namespace().vars
        it("can do variable capture of simple value", function()
            local matched, captures = m.match(V.v, 55)
            assert.is.truthy(matched)
            assert.is.equal(55, captures.v)
        end)
        it("captures a variable by name", function()
            local matched, captures = m.match({x=V.v}, {a={3,{x=88}}})
            assert.is.truthy(matched)
            assert.is.equal(88, captures.v)
        end)
        it("captures multiple variables by name", function()
            local matched, captures = m.match({x=V.x,y=V.y}, 
                                                {a={3,{x=88,y=77}}})
            assert.is.truthy(matched)
            assert.is.equal(88, captures.x)
            assert.is.equal(77, captures.y)
        end)
        it("captures variables by index", function()
            local matched, captures = m.match({x=V[1]}, {a={3,{x=88}}})
            assert.is.truthy(matched)
            assert.is.equal(88, captures[1])
        end)
        it("captures arrays of variables when matching all", function()
            local matched, captures = m.match_all({x=V[1],y=V[2]}, 
                                                {{x=1,y=2},{x=10,y=20}})
            assert.is.truthy(matched)
            assert.is.same({{1,2},{10,20}}, captures)
        end)
        it("enforces match of previously captured variables", function()
            local matched, captures = m.match({V[1],V[2],V[1]},
                                                {1,2,1})
            assert.is.truthy(matched)
            assert.is.same({1,2}, captures)

            local matched, captures = m.match({V[1],V[2],V[1]},
                                                {1,2,3})
            assert.is_nil(matched)
            assert.is.same({}, captures)
        end)
        it("uses table match for previously captured variables", function()
            local matched, captures = m.match({V[1],V[2],V[1]},
                                                {{1,2},{5},{1,2}})
            assert.is.truthy(matched)
            assert.is.same({{1,2},{5}}, captures)

            local matched, captures = m.match({V[1],V[2],V[1]},
                                                {{1,2},{5},{1,3}})
            assert.is_nil(matched)
            assert.is.same({}, captures)
        end)
        it("uses table match for previously captured keys and/or variables", function()
            local K = m.namespace().keys
            local V = m.namespace().vars
            local matched, captures = m.match({{h=V.x},{K.x}},
                                                {{h=3},{x=3}})
            assert.is.truthy(matched)
            assert.is.same({x=3}, captures)

            local matched, captures = m.match({{h=V.y},{K.y}},
                                                {{h=3},{x=4}})
            assert.is.falsy(matched)
            assert.is.same({}, captures)

        end)
        it("finds an element in an array returning its index in a variable", function()
            assert.is.truthy(m.match({[V.index] = "b"}, {"a", "b", "c"}))

            assert.is.equal(2, V.index.value)
            assert.is.equal(2, V.index())
        end)
        it("can retrieve the variables after their use (needed for pattern dispatch)", function()
            local X, Y = V.x, V.y
            local matched, captures, vars = m.match({X, Y}, {1, 2})
            assert.is.equal('x', vars[X])
            assert.is.equal('y', vars[Y])
            assert.is.equal(1, X())
            assert.is.equal(2, Y())
        end)
        it("keeps the last variable matched value in vars when a match_all is performed", function()
            local X = V.x
            local matched, captures, vars = m.match_all(X, {1, 1, 1})
            assert.is.same({1,1,1}, matched)
            assert.is.equal(1, X())

            local X = V.x
            local matched, captures, vars = m.match_all(X, {1, 1, 2})
            assert.is.truthy(matched)
            assert.is.same({1,1,2}, matched)
            assert.is.equal(2, X())     -- last value
        end)
        it("fails to find when there are no matches", function()
            local z = m.find({z=V[1]}, {{a=8,x=3,y=4}})
            assert.is_nil(z)
        end)
        it("can find and return multiple matched variables for convenience of extraction", function()
            local y, x = m.find({x=V[2], y=V[1]}, {{a=8,x=3,y=4}})
            assert.is.equal(4, y)
            assert.is.equal(3, x)
        end)
        it("can find and return a table of matched variables for convenience of extraction", function()
            local vars = m.find({x=V.x, y=V.y}, {{a=8,x=3,y=4}})
            assert.is.equal(4, vars.y)
            assert.is.equal(3, vars.x)
        end)
        it("can find and return a table of matched keys for convenience of extraction", function()
            local K = m.namespace().keys
            local vars = m.find({K.x, K.y}, {{a=8,x=3,y=4}})
            assert.is.equal(4, vars.y)
            assert.is.equal(3, vars.x)
        end)
    end)
    describe("complex conditional nested key/variable matches", function()
        it("matches keys conditionally a higher tree with its subtree and an element within that tree, non cyclical", function()
            local N = m.namespace()
            local K = N.keys
            local V = N.vars
            local t = {
                A = {
                    x = 5,
                },
                B = {
                }
            }
            t.A.b = t.B
            local matching_set, captures, vars = m.match_root(
                { K.A({ K.b }) }, t)
            assert.is.truthy(matching_set)
            assert.is.equal(captures.b, t.B)
            assert.is.equal(captures.A, t.A)
        end)
        it("matches variable conditionally a higher tree with its subtree and an element within that tree, non cyclical", function()
            local N = m.namespace()
            local K = N.keys
            local V = N.vars
            local t = {
                A = {
                    x = 5,
                },
                B = {
                }
            }
            t.A.b = t.B
            local matching_set, captures, vars = m.match_root(
                { A = V.A({ b = V.B }) }, t)
            assert.is.truthy(matching_set)
            assert.is.equal(captures.B, t.B)
            assert.is.equal(captures.A.b, t.B)
        end)
        it("matches key conditionally in a cyclical tree", function()
            local N = m.namespace()
            local K = N.keys
            local V = N.vars
            local t = {
                A = {
                    x = 5,
                },
                B = {
                }
            }
            t.A.B = t.B
            t.B.A = t.A
            local matching_set, captures, vars = m.match_root(
                { K.A({ K.B({ K.A }) }) }, t)
            assert.is.truthy(matching_set)
            -- higher level variable A is the same as lower level t.B.a
            assert.is.equal(captures.B, t.B)
            assert.is.equal(captures.A.B, t.B)
            assert.is.equal(captures.B.A, t.A)
        end)
        it("matches variable conditionally in a cyclical tree", function()
            local N = m.namespace()
            local K = N.keys
            local V = N.vars
            local t = {
                A = {
                    x = 5,
                },
                B = {
                }
            }
            t.A.b = t.B
            t.B.a = t.A
            local matching_set, captures, vars = m.match_root(
                { A = V.A({ b = V.B({ a = V.A }) }) }, t)
            assert.is.truthy(matching_set)
            -- higher level variable A is the same as lower level t.B.a
            assert.is.equal(captures.B, t.B)
            assert.is.equal(captures.A.b, t.B)
            assert.is.equal(captures.B.a, t.A)
        end)
        it("matches variables somewhere in a tree", function()
            local N = m.namespace()
            local K = N.keys
            local V = N.vars
            local t = {
                A = {
                    { a = { x = 1 } },
                    { b = { y = 2 } },
                    { c = { z = 3 } }
                },
                B = {
                    { a = { x = 4 } },
                    { b = { y = 5 } },
                    { c = { z = 6 } }
                }
            }
            local matching_set, captures, vars = m.match_root(
                { [m.key] = V.top{ [m.key] = V.element{ [m.key] = V.leaf{ [V.xyz] = 5 } } } }, t)
            assert.is.same({b={y=5}}, captures.element)
            assert.is.same({y=5}, captures.leaf)
            assert.is.same("y", captures.xyz)
        end)
        it("matches variables somewhere in a tree, including variables for keys", function()
            local N = m.namespace()
            local K = N.keys
            local V = N.vars
            local t = {
                A = {
                    { a = { x = 1 } },
                    { b = { y = 2 } },
                    { c = { z = 3 } }
                },
                B = {
                    { a = { x = 4 } },
                    { b = { y = 5 } },
                    { c = { z = 6 } }
                }
            }
            local matching_set, captures, vars = m.match_root(
                { [V.top_key] = V.top{ [V.index] = V.element{ [V.abc_key] = V.leaf{ [V.xyz] = 5 } } } }, t)
            assert.is.equal("B", captures.top_key)
            assert.is.equal(2, captures.index)
            assert.is.same({b={y=5}}, captures.element)
            assert.is.equal("b", captures.abc_key)
            assert.is.same({y=5}, captures.leaf)
            assert.is.same("y", captures.xyz)
        end)
        it("matches variables scattered recursively in a tree under values, not keys", function()
            local N = m.namespace()
            local K = N.keys
            local V = N.vars
            local t = {
                A = {
                    { a = { x = 1 } },
                    { b = { y = 2 } },
                    { c = { z = 3 } }
                }
            }
            local matching_set, captures, vars = m.match_root(
                { A = V.A{ V.first{ a = V.leaf{ x = V.x } } } }, t)
            assert.is.same({a={x=1}}, captures.first)
            assert.is.same({x=1}, captures.leaf)
            assert.is.same(1, captures.x)
        end)
        it("errors meaningfully when trying to do reconciliation of vars within a key variable nested search", function()
            local N = m.namespace()
            local K = N.keys
            local V = N.vars
            local t = {
                target = 6,
                A = {
                    { a = { x = 1 } },
                    { b = { y = 2 } },
                    { c = { z = 3 } }
                },
                B = {
                    { a = { x = 4 } },
                    { b = { y = 5 } },
                    { c = { z = 6 } }
                }
            }
            assert.is.error(function()
                local matching_set, captures, vars = m.match_root(
                    { target = V.target,
                      [V.top_key] = V.top{ [V.index] = V.element{ [V.abc_key] = V.leaf{ [V.xyz] = V.target } } } }, t)
                end, "Variable reconciliation not supported for key matching. Key: target. Use another variable name if reconciliation is not desired.")
        end)
        it("fails to match a cyclical pattern in a non-cyclical tree", function()
            local N = m.namespace()
            local K = N.keys
            local V = N.vars
            local t = {
                A = {
                    x = 5,
                },
                B = {
                    a = {}
                }
            }
            t.A.b = t.B
            local matching_set, captures, vars = m.match_root(
                { A = V.A({ b = V.B({ a = V.A }) }) }, t)
            -- variable A at top is not same it B.a
            assert.is.falsy(matching_set)
        end)
        it("Expands K abbreviations in variable predicates", function()
            local N = m.namespace()
            local K = N.keys
            local V = N.vars
            local t = {
                { a = "a", b = 1 },
                { a = "b", b = 2 },
                { a = "c", b = 3 },
                { a = "d", b = 4 },
                { a = "e", b = 5 },
            }
            local matching_set, captures = m.match_root(
                { [V.index] = V.element{ a = "c", K.b } }, t)
            assert.is.equal(3, captures.b)
            assert.is.equal("c", captures.element.a)
        end)
    end)
end)

describe("matcher", function()
    local function is_even(x) return x % 2 == 0 end
    local function f(x) end
    local function receive_match(matched_set)
        matched_set.id = 32
        return matched_set
    end

    local N = m.namespace()
    local V = N.vars
    local K = N.keys
    local unique_object = {}
    local matcher = m.matcher{
        { 1,                          "one" },
        { {"matched"},                m.matched_value },
        { "unique",                   m.as_is(unique_object) },
--        { {even = V('n', is_even)},   V.n },      -- conditional variables
        { {even = V.n(is_even)},      V.n },      -- conditional variables
        { {x=V.x},                    V.x},
        { {sum={a=V.a,b=V.b}},        function(vars) return vars.a + vars.b end },
                                      -- unpacked positional variables
        { {div={V[1],V[2]}},          function(a, b) return a / b end },
        { {v={V.a, V.b}},             {p=V.a, q=V.b}},
        { {v={a=V.a, b=V.b}},         {pp=V.a, qq={b=V.b}, {[V.a]=V.b}}},
        { {V=V.x},                    {X=V.x} },
        { {K.X, K.Y},                 {V.X, V.Y}, 
                where = function(point) return point.X > point.Y end },
        { {K.X, K.Y},                 false, 
                where = function(point) return point.X <= point.Y end },
        { {">", V[1], V[2]},         true, 
                where = function(left, right) return left > right end },
        { {">", V[1], V[2]},         false, 
                where = function(left, right) return left < right end },
        { {F=V.x},                    m.as_is(f) },
        { {a=1,b=2},                  receive_match },
        { m.otherwise,                "catch-all value" },
    }
    it("applies matched value transform", function()
        assert.is.same({"matched"}, matcher({"matched"}))
    end)
    it("leaves matched result as_is", function()
        assert.is.equal(unique_object, matcher("unique"))
    end)
    it("avoids calling functions automatically with as_is", function()
        assert.is.equal(f, matcher({F=3}))
    end)
    it("applies variable bound value transformation", function()
        assert.is.equal(3, matcher({x=3}))
    end)
    it("matches and captures conditional variables (variables with a predicate)", function()
        assert.is.equal("catch-all value", matcher({even=3}))
        assert.is_nil(V.n())
        assert.is.equal(4, matcher({even=4}))
        assert.is.equal(4, V.n())
    end)
    it("applies matching const transform", function()
        assert.is.equal("one", matcher(1))
        assert.is.equal("catch-all value", matcher(5))
    end)
    it("applies matching custom function transform with whole matched set", function()
        assert.is.same({id=32,a=1,b=2}, matcher{a=1,b=2,z=3})
    end)
    it("applies matching custom function transform with captures", function()
        assert.is.equal(5, matcher{sum={a=2,b=3}})
    end)
    it("applies matching custom function transform with unpacked positional numeric variables", function()
        assert.is.equal(2, matcher{div={10,5}})
    end)
    it("applies variable substitution in transform table", function()
        assert.is.same({p=2,q=3}, matcher{v={2,3}})
    end)
    it("applies multiple variable substitution (key and value) in transform table", function()
        assert.is.same({pp='x',qq={b='y'}, {x='y'}}, matcher{v={a='x',b='y'}})
    end)
    it("Rebinds variables accross repeated calls", function()
        assert.is.same({X=5}, matcher{V=5})
        assert.is.same({X="a"}, matcher{V="a"})
    end)
    it("can use an optional where condition to further test the patterns", function()
        assert.is.same({2,1}, matcher{X=2,Y=1})
        assert.is.equal(false, matcher{X=1,Y=2})
    end)
    it("can use an optional where condition with positional parameters", function()
        assert.is.equal(true, matcher{">", 2, 1})
        assert.is.equal(false, matcher{">", 1, 2})
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
    it("errors out when trying to reference a variable that hasn't been bound", function()
        local var_scope = m.namespace().vars
        local matcher = m.matcher{
            { {x=var_scope.x}, var_scope.y }
        }
        assert.is.error(function() matcher({x=3}) end, 
            "Trying to apply unbound variable 'y'")
    end)
    it("errors out when trying to apply transform with unbounded variable with equally-named variable in match (two variable instances with same name)", function()
        local var_scope_a = m.namespace().vars
        local var_scope_b = m.namespace().vars
        local matcher = m.matcher{
            { {x=var_scope_a.x}, var_scope_b.x }
        }
        assert.is.error(function() matcher({x=3}) end, 
            "Possibly trying to apply an unbound variable with same name as bound variable 'x': Make sure to use the same namespace for vars in the match and its transform (#1)")
    end)
    it("can use variables captured through keys in consequent", function()
        local N = m.namespace()
        local K = N.keys
        local V = N.vars
        local matcher = m.matcher{
            { {K.x}, V.x }
        }
        assert.is.equal(3, matcher({x=3}))
    end)
    describe("enforcement of specific vs general rule selection policies", function()
        it("Errors out when a more general rule is defined earlier than a more specific matching rule", function()
            local match_fn, err = pcall(function() return m.matcher{
                name = "backwards_pattern",
                { { "a" }, "general" },
                { { "a", "b" }, "specific" }
            } end)
            assert.is_falsy(match_fn)
            assert.is.truthy(err:find("Unreachable rule " 
                       .. 2 .. " due to more general, or duplicated, prior rule " 
                       .. 1))
        end)
        it("Errors out when a more general rule is defined earlier than a more specific matching rule, recursively", function()
            local match_fn, err = pcall(function() return m.matcher{
                name = "backwards_pattern",
                { { a = { "a" } }, "general" },
                { { a = { "a", "b" } }, "specific" }
            } end)
            assert.is_falsy(match_fn)
            assert.is.truthy(err:find("Unreachable rule " 
                       .. 2 .. " due to more general, or duplicated, prior rule " 
                       .. 1))

            local match_fn, res = pcall(function() return m.matcher{
                name = "forward_pattern",
                { { a = { "a", "b" } }, "specific" },
                { { a = { "a" } }, "general" }
            } end)
            assert.is_truthy(match_fn)
            assert.is.same("function", type(res))
        end)
        it("Errors out when a rule has either a nil match or a nil consequent", function()
            local bad_namespace = {}
            local match_fn, err = pcall(function() return m.matcher{
                name = "nil_consequent",
                { { a = { "a" } }, bad_namespace.x }
            } end)

            assert.is_falsy(match_fn)
            assert.is.truthy(err:find("nil consequent in rule #1, in nil_consequent matcher"))

            local match_fn, err = pcall(function() return m.matcher{
                name = "nil_antecedent",
                { nil, 1 }
            } end)

            assert.is_falsy(match_fn)
            assert.is.truthy(err:find("nil antecedent in rule #1, in nil_antecedent matcher"))
        end)
    end)
    describe("variable transformations", function()
        local N = m.namespace()
        local K = N.keys
        local V = N.vars
        local T = N.transforms

        it("applies consequent transformations to vars", function()
            local function double(x) return 2 * x end
            local p = m.matcher{
                name = "transform",
                { { K.a }, { x = T.a(double) } }
            }
            assert.is.same({ x = 10 }, p{ a = 5 })
        end)
        it("can do both: predicates and transformations to vars", function()
            local function is_even(x) return x % 2 == 0 end
            local function double(x) return 2 * x end
            local p = m.matcher{
                name = "transform",
                { { K.a(is_even) }, { x = T.a(double) } }
            }
            assert.is.same({ x = 8 }, p{ a = 4 })
            assert.is_nil(p{ a = 3 })
        end)
        it("chains multiple transformations in a var", function()
            local function is_even(x) return x % 2 == 0 end
            local function double(x) return 2 * x end
            local p = m.matcher{
                name = "transform",
                { { K.a(is_even) }, { x = T.a(double, double) } }
            }
            assert.is.same({ x = 16 }, p{ a = 4 })
            assert.is_nil(p{ a = 3 })
        end)
        it("does independent transformations on same var", function()
            local function is_even(x) return x % 2 == 0 end
            local function double(x) return 2 * x end
            local p = m.matcher{
                name = "transform",
                { { K.a(is_even) }, { x = T.a(double, double), even = T.a(is_even) } }
            }
            assert.is.same({ x = 16, even = true }, p{ a = 4 })
        end)
        it("fails to perform a transformation on an unbound var", function()
            local function double(x) return 2 * x end
            local p = m.matcher{
                name = "transform",
                { { K.a }, { x = T.b(double) } }
            }
            assert.is.error(function() p{ a = 4 } end, "Unbound variable b in transform")
        end)
    end)
end)
