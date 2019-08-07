local var_proof = {}        -- unique value to recognize variable functions

local function is_var(x)
    return type(x) == "table" and rawget(x, var_proof)
end

local function is_empty_table(t)
    for _, _ in pairs(t) do
        return nil
    end
    return true
end

local function table_size(t)
    local len = 0
    for _, _ in pairs(t) do
        len = len + 1
    end
    return len
end

local function is_array(t)
    if type(t) ~= "table" or is_var(t) then
        return nil
    end

    local size = table_size(t)
    for i=1,size do
        if t[i] == nil then
            return nil
        end
    end
    return t
end

local function value_if(fn)
    return function(x)
        if fn(x) then return x end
        return nil
    end
end

local function is_number(x)
    return type(x) == "number" and x or nil
end

local function is_string(x)
    return type(x) == "string" and x or nil
end

local function is_boolean(x)
    if type(x) == "boolean" then return x end
    return nil
end

local function is_function(x)
    return type(x) == "function" and x or nil
end

local function is_table(x)
    return type(x) == "table" and not is_var(x) and x or nil
end

local function is_like(regex)
    return function(x)
        return type(x) == "string" and x:match(regex) and x or nil
    end
end

-- deepcompare taken from: 
-- http://snippets.luacode.org/snippets/Deep_Comparison_of_Two_Values_3
local function deepcompare(t1,t2,ignore_mt)
    local ty1 = type(t1)
    local ty2 = type(t2)
    if ty1 ~= ty2 then return false end
    -- non-table types can be directly compared
    if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
    -- as well as tables which have the metamethod __eq
    local mt = getmetatable(t1)
    if not ignore_mt and mt and mt.__eq then return t1 == t2 end
    for k1,v1 in pairs(t1) do
    local v2 = t2[k1]
    if v2 == nil or not deepcompare(v1,v2) then return false end
    end
    for k2,v2 in pairs(t2) do
    local v1 = t1[k2]
    if v1 == nil or not deepcompare(v1,v2) then return false end
    end
    return true
end

local function id(v) return function(x) return v == x and v or nil end end
local function value(v) return v end
local function otherwise(v) return v end

local default_values_to_promises = {}
local default_promises = {}
local function default_value(x) 
    local default_promise = default_values_to_promises[x]
    if default_promise then return default_promise end
    default_promise = function() return x end
    default_values_to_promises[x] = default_promise
    default_promises[default_promise] = true
    return default_promise
end

local function key(k) return k end
local function tail(t, k)
    assert(is_array(t), "tail can be applied only to arrays")
    assert(type(k) == "number", "Invalid key: '" .. k .. "' of type " .. type(k))
    local res = {}
    for i=k,#t do
        table.insert(res, t[i])
    end
    return res
end
local function rest(t, present)
    local res = {}
    for ik, iv in pairs(t) do
        if not present[ik] or present[ik] == rest then
            res[ik] = iv
        end
    end
    return res
end
local function nothing(t, present)
    for ik, iv in pairs(t) do
        if present[ik] ~= key and (not present[ik] or present[ik] == nothing) then
            return nil
        end
    end
    return nothing
end

local function tail_promise() end
local function rest_promise() end
local function nothing_promise() end
local function optional() end
local function missing() end

local function var(var_name, predicate)
    local bound_value
    return function(value)
        if value == nil then
            return bound_value, var_name
        end
        if predicate and not predicate(value) then
            return nil, nil
        end
--        if bound_value == nil then    -- sticky bound or updatable?
            bound_value = value
--        end
        return value, var_name, var_proof
    end
end

local key_id = {}
local unbound = {}

local function namespace()
    local vs = {}
    local ns = {}

    local v_mt = {
        __call = function(var_table, ...)
            local predicate_fns = {...}
            if #predicate_fns == 0 then
                -- TODO: temporary. this is to make tests pass where the 
                    -- value of the variable is accessed as a call with
                    -- no arguments
                if var_table.value == unbound then
                    return nil
                end
--                assert(var_table.value ~= unbound, "Variable " .. var_table.name .. " is unbound")
                return var_table.value
            end
            for _, p in ipairs(predicate_fns) do
                assert(type(p) == "function" or type(p) == "table", "variable predicates must be functions or tables (that can get recursively matched)")
            end
            var_table.predicates = predicate_fns
            return var_table
        end
    }
    local function new_var(name)
        local v = {
            [var_proof] = name,
            name = name,
            value = unbound,
            namespace = ns,
            predicates = { }
        }
        ns[name] = v
        setmetatable(v, v_mt)
        return v
    end

    local function vars()
        local mt = {
            __index = function(t, k)
                local v = ns[k] or new_var(k)
                return v
            end
        }
        setmetatable(vs, mt)
        return vs
    end

    local vars_instance = vars()

    local function keys()
        local keys_namespace = {}
        local k_mt = {
            __call = function(key_table, ...)
                local predicate_fns = {...}
                assert(#predicate_fns > 0, "At least one predicate (function or table) should be provided when parenthesis are used after a key")
                for _, p in ipairs(predicate_fns) do
                    assert(type(p) == "function" or type(p) == "table", "keys predicates must be functions or tables (that can get recursively matched)")
                end
                key_table.predicates = predicate_fns
                return key_table
            end
        }
        local mt = {
            __index = function(t, k)
                local v = vars_instance[k]
                local key = {
                    [key_id] = k,
                    name = k,
                    variable = v,
                    vars = vars_instance,
                    predicates = false
                }
                setmetatable(key, k_mt)
                return key
            end
        }
        setmetatable(keys_namespace, mt)
        return keys_namespace
    end

    local keys_instance = keys()

    return {
        vars = vars_instance,
        keys = keys_instance
    }
end

local function is_key(x)
    return type(x) == "table" and rawget(x, key_id)
end

local function match_empties(a, b)
    if is_empty_table(a) and is_empty_table(b) then
        return {}
    end
end

local function match_root( pattern, target)
--    local V = vars()
    local captures = {}
    local vars = {}
    local resolve_promises = false
    local second_pass = false
    local predicated_variables = {}

    local function match_root_recursive(pattern, target)
        local function key_in_table(t, k, v)
            if k == key then
                return function(t, key_fn, value)
                    for k, v in pairs(t) do
                        local res = match_root_recursive( value, t[k])
                        if res ~= nil then 
                            return res, k 
                        end
                    end
                    return nil
                end, k
            end
            if is_var(k) then
                return function(t, key_var, value)
                    for k, v in pairs(t) do
                        local res = match_root_recursive( value, v)
                        if res ~= nil then 
                            for _, predicate in ipairs(key_var.predicates) do
                                if type(predicate) == "function" then
                                    if not predicate(res) then
                                        return nil
                                    end
                                else
                                    assert(false, "only functions are supported as key predicates")
                                end
                            end

                            key_var.value = k
                            return res, k 
                        end
                    end
                    return nil
                end, k
            end

            assert(type(k) ~= "function", "Functions as keys are not supported")

            if v == tail_promise and is_array(t) then
                resolve_promises = true
                return function(t, _, _)
                    return tail, k
                end, k
            end
            if v == rest_promise then
                resolve_promises = true
                return function(t, _, _)
                    return rest, k
                end, k
            end
            if v == nothing_promise then
                resolve_promises = true
                return function(t, _, _)
                    return nothing, k
                end, k
            end
            if v == optional then
                if second_pass then
                    return function(t, _, _)
                        return nothing, k
                    end, k
                else
                    return function(t, key, _)
                        local v = t[key]
                        if v ~= nil then return v, key end
                        resolve_promises = true
                        return optional, k
                    end, k
                end
            end
            if v == missing then
                return function(t, key, _)
                    local v = t[key]
                    if v == nil then return missing, key end
                    return nil, k
                end, k
            end
            if v == tail and is_array(t) then
                return function(t, _, _)
                    return tail(t, k), k
                end, k
            end
            if v == rest then
                return function(t, _, _)
                    return rest(t, pattern), k, true        -- splat
                end, k
            end
            if v == nothing then
                return function(t, _, _)
                    return nothing(t, pattern), k
                end, k
            end
            local value_promise = default_promises[v] 
            if value_promise then
                return function(t, _, _)
                    local value = t[k]
                    if value ~= nil then return value, k end
                    return v(), k
                end, k
            end
            if t[k] ~= nil then 
                return function(t, k, v) return match_root_recursive( v, t[k]), k end, k
            else
                return function() return nil, nil end, k
            end
        end

        if target == pattern then return target end

        if is_var(pattern) then
            local var_name = pattern.name
            if captures[var_name] ~= nil and not deepcompare(target, captures[var_name]) then
                return nil
            end

            for _, predicate in ipairs(pattern.predicates) do
                if type(predicate) == "function" then
                    if not predicate(target) then
                        return nil
                    end
                elseif type(predicate) == "table" then
                    for i, predicated_var in ipairs(predicated_variables) do
                        if predicated_var.name == var_name then
                            if target ~= predicated_var.tentative_value then
                                return nil
                            end
                            captures[var_name] = target
                            pattern.value = target
                            vars[pattern] = var_name
                            return target
                        end
                    end
                    table.insert(predicated_variables, {
                            name = var_name,
                            tentative_value = target})
                    if not match_root_recursive(predicate, target) then
                        return nil
                    end
                    table.remove(predicated_variables)
                else
                    assert(false, "only functions and tables are supported as variable predicates")
                end
            end

            captures[var_name] = target
            pattern.value = target
            vars[pattern] = var_name
            return target
        end

        if type(pattern) == "function" then
            return pattern(target)
        end
        if type(target) ~= type(pattern) then return nil end
        if is_table(pattern) then
            local res = match_empties( pattern, target) 
            if res ~= nil then return res end

            local matches = {}
            local did_match = true
            local at_least_one = false
            for k, v in pairs(pattern) do
                local matcher, key = key_in_table(target, k, v)
                if key ~= nil then
                    local match_result, matched_k, splat = matcher(target, key, v)
                    if match_result ~= nil or match_result == missing then
                        if splat then
                            for k, v in pairs(match_result) do
                                matches[k] = v
                            end
                        else
                            if (not second_pass or match_result ~= nothing)
                                and match_result ~= missing then
                                matches[matched_k] = match_result
                            end
                        end
                        at_least_one = true
                    else
                        did_match = false
                    end
                else
                    did_match = false
                end
            end
            return did_match and at_least_one and matches or nil
        end
        return nil
    end

    local function expand_key_abbreviations(pattern)
        if is_table(pattern) then
            if pattern[key_id] then
                return pattern.vars[pattern[key_id]]
            end
            local expanded_pattern = {}
            for k, v in pairs(pattern) do
                if is_table(v) and v[key_id] then
                    local new_var = v.vars[v[key_id]]
                    if v.predicates then
                        local expanded_predicates = {}
                        for _, predicate in ipairs(v.predicates) do
                            if type(predicate) == "table" then
                                table.insert(expanded_predicates, expand_key_abbreviations(predicate))
                            else
                                table.insert(expanded_predicates, predicate)
                            end
                        end
                        expanded_pattern[v[key_id]] = new_var(unpack(expanded_predicates))
                    else
                        expanded_pattern[v[key_id]] =  new_var
                    end
                else
                    expanded_pattern[k] = expand_key_abbreviations(v)
                end
            end
            return expanded_pattern
        else
            return pattern
        end
    end

    local expanded_pattern = expand_key_abbreviations(pattern)
    local matched_table = match_root_recursive(expanded_pattern, target)

    if resolve_promises then
        second_pass = true
        matched_table = match_root_recursive(matched_table, target)
    end
    
    return matched_table, captures, vars
end

local function either(...)
    local options = {...}
    return function(x)
        for _, v in ipairs(options) do
            local res = match_root(v, x)
            if res ~= nil then
                return res 
            end
        end
        return nil
    end
end

local function match(pattern, target, visited)
    local res, captures, vars = match_root( pattern, target)
    if res ~= nil then return res, captures, vars end

    if type(target) == "table" then
        visited = visited or {}
        visited[target] = true
        for k, v in pairs(target) do
            if type(v) == "table" then
                if not visited[v] then
                    local res, captures, vars = match( pattern, v, visited)
                    if res ~= nil then return res, captures, vars end
                end
            end
        end
    end
    return nil, {}, {}
end

local function find(pattern, target)
    local res, captures, vars = match(pattern, target)
    if res then
        local values = {}
        for v, i in pairs(vars) do
            values[i] = v()
        end
        if is_array(values) then
            return unpack(values)
        else
            return values
        end
    end
    return nil
end

local function match_all(pattern, target, visited)
    local capture_array = {}
    local var_array = {}

    if type(target) == "table" then
        local matched = {}
        visited = visited or {}
        visited[target] = true
        for k, v in pairs(target) do
            if not visited[v] then
                local res, captures, vars = match(pattern, v, visited)
                if res ~= nil then 
                    table.insert(matched, res) 
                    table.insert(capture_array, captures)
                    table.insert(var_array, vars)
                end
            end
        end
        return matched, capture_array, var_array
    else
        local res, captures, vars = match_root( pattern, target)
        if res ~= nil then return res, { captures }, { vars } end
    end
    return {}, {}, {}
end

local is_const_transform_type = {
    number = true,
    string = true,
    boolean = true
}

local function matched_value() end

local function apply_vars(t, vars, rule_n)
    local res = {}
    for k, v in pairs(t) do
        local key, value = k, v
        if is_var(k) then
            key = k.value
        end
--        if type(k) == "function" and vars[k] then
--            key = k()
--        end
        if is_var(v) then
            if v.value == unbound then
                for _, var_name in pairs(vars) do
                    if var_name == v.name then
                        error("Possibly trying to apply an unbound variable with same name as bound variable '" 
                                .. var_name 
                                .. "': Make sure to use the same namespace for vars in the match and its transform (#" 
                                .. (rule_n or "?") .. ")")
                    end
                end
                error("Trying to apply unbound variable '" .. v.name .. "'")
            end
            value = v.value
        elseif type(v) == "table" then
            value = apply_vars(value, vars, rule_n)
        elseif type(v) == "function" and vars[v] then
            value = v()
        end
        res[key] = value
    end
    return res
end

local function as_is(value)
    return function() return value end
end

local function apply_match(transform, matched, captures, vars, n)
    if transform == as_is then
        return transform
    elseif transform == matched_value then
        return matched
    elseif vars[transform] then
        return transform()
--    elseif is_var(transform) then
--        assert(transform.value ~= unbounded, "Trying to apply unbound variable '" .. transform.name .. "'")
--        return transform.value
    elseif type(transform) == "function" then
        if is_empty_table(captures) then
            return transform(matched)
        else
            if is_array(captures) then
                return transform(unpack(captures))
            else
                return transform(captures)
            end
        end
    elseif is_const_transform_type[type(transform)] then
        return transform
    elseif type(transform) == "table" then
        return apply_vars(transform, vars, n)
    else
        error("what type of transform is this? " .. type(transform))
    end
end

local function specificity(obj, specificity_so_far)
    specificity_so_far = specificity_so_far or 1

    if type(obj) == "table" then
        for _, value in pairs(obj) do
            specificity_so_far = specificity_so_far + 1
            if type(value) == "table" then
                specificity_so_far = specificity(value, specificity_so_far)
            end
        end
    end
    return specificity_so_far
end

local function is_subset_of(superset, subset)
    if type(superset) == "table" and type(subset) == "table" then
        for k, v in pairs(subset) do
            local supervalue = superset[k]
            if type(v) == "function" or type(supervalue) == "function" then
                return false
            end
            -- TODO: does this really check for subset in vars???
            if is_key(v) then
                if not is_key(supervalue) or v.name ~= supervalue.name then
                    return false
                end
            elseif is_var(v) then
                if not is_var(supervalue) or v.name ~= supervalue.name then
                    return false
                end
            elseif type(v) == "table" then
                if type(superset[k]) == "table" then
                    local value_is_subset = is_subset_of(superset[k], v)
                    if not value_is_subset then
                        return false
                    end
                else
                    return false
                end
            else
                if supervalue ~= v then
                    return false
                end
            end
        end
    elseif superset ~= subset then
        return false
    end
    return true
end

local function check_otherwise_is_last(rules)
   for i, rule in ipairs(rules) do
        if rule[1] == otherwise then
            if i ~= #rules then
                error("The 'otherwise' clause must be the last in the rules, here found in clause " 
                       .. i .. " of " .. #rules)
            end
        end
   end
end

local function check_specific_to_general_ordering(rules)
    for i=1,#rules do
        for j=i+1,#rules do
            if is_subset_of(rules[j][1], rules[i][1]) then
                error("Unreachable rule " 
                       .. j .. " due to more general, or duplicated, prior rule " 
                       .. i)
            end
        end
    end
end

local function check_for_nils_in_rules(rules)
    for i=1,#rules do
        if rules[i][1] == nil then
            error("nil antecedent in rule #" .. i .. ", in " .. (rules.name or "anonymous") .. " matcher")
        end
        if rules[i][2] == nil then
            error("nil consequent in rule #" .. i .. ", in " .. (rules.name or "anonymous") .. " matcher")
        end
    end
end

local function matcher(match_pairs)
    check_otherwise_is_last(match_pairs)
    check_specific_to_general_ordering(match_pairs)
    check_for_nils_in_rules(match_pairs)

    return function(target)
        local matching_rules = {}
        for i, match_pair in ipairs(match_pairs) do
            local matched, captures, vars = match_root(match_pair[1], target)
            if matched ~= nil then
--                return apply_match(match_pair[2], matched, captures, vars, i), matched, i
                return apply_match(match_pair[2], matched, captures, vars, i), matched, vars, i
            end
        end
    end
end

return {
    key = key,
    value = value,
    unbound = unbound,
    otherwise = otherwise,
    optional = optional,
    missing = missing,
    default_value = default_value,
    head = value,
    rest = rest_promise,
    nothing = nothing_promise,
    nothing_else = nothing_promise,
    tail = tail_promise,
    namespace = namespace,
--    keys = keys,
--    vars = vars,
    match_root = match_root,
    match = match,
    apply_vars = apply_vars,
    find = find,
    match_all = match_all,
    matcher = matcher,
    matched_value = matched_value,
    as_is = as_is,
    id = id,
    value_if = value_if,
    is_var = is_var,
    is_number = is_number,
    is_string = is_string,
    is_boolean = is_boolean,
    is_function = is_function,
    is_table = is_table,
    is_array = is_array,
    is_like = is_like,
    either = either
}
