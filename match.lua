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
    if type(t) ~= "table" then
        return nil
    end

    local size = table_size(t)
    for i=1,size do
        if rawget(t,i) == nil then
            return nil
        end
    end
    return t
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
    return type(x) == "table" and x or nil
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
    local v2 = rawget(t2,k1)
    if v2 == nil or not deepcompare(v1,v2) then return false end
    end
    for k2,v2 in pairs(t2) do
    local v1 = rawget(t1,k2)
    if v1 == nil or not deepcompare(v1,v2) then return false end
    end
    return true
end

local function id(v) return function(x) return v == x and v or nil end end
local function value(v) return v end

--local function default_value(default) 
--    return function(x) return x ~= nil and x or default end 
--end
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
        table.insert(res, rawget(t,i))
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

local var_proof = {}        -- unique value to recognize variable functions

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

local function vars()
    local vs = {}
    local mt = {
        __index = function(t, k)
            local v = var(k)
            vs[k] = v
            return v
        end,
        __call = function(t, var_name, predicate)
            local v = var(var_name, predicate)
            vs[var_name] = v
            return v
        end
    }
    setmetatable(vs, mt)
    return vs
end

local function match_empties(a, b)
    if is_empty_table(a) and is_empty_table(b) then
        return {}
    end
end

local function match_root( pattern, target)
    local captures = {}
    local vars = {}
    local resolve_promises = false
    local second_pass = false
    local function match_root_recursive(pattern, target)
        local function key_in_table(t, k, v)
            if k == key then
                return function(t, key_fn, value)
                    for k, v in pairs(t) do
                        local res = match_root_recursive( value, rawget(t,k))
                        if res ~= nil then 
                            return res, k 
                        end
                    end
                    return nil
                end, k
            end
            if type(k) == "function" then
                local maybe_key_var = k
                return function(t, key_fn, value)
                    for k, v in pairs(t) do
                        local res = match_root_recursive( value, rawget(t,k))
                        if res ~= nil then 
                            maybe_key_var(k)
                            return res, k 
                        end
                    end
                    return nil
                end, k
            end
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
                        local v = rawget(t, key)
                        if v ~= nil then return v, key end
                        resolve_promises = true
                        return optional, k
                    end, k
                end
            end
            if v == missing then
                return function(t, key, _)
                    local v = rawget(t, key)
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
                    local value = rawget(t, k)
                    if value ~= nil then return value, k end
                    return v(), k
                end, k
            end
            if rawget(t,k) ~= nil then 
                return function(t, k, v) return match_root_recursive( v, rawget(t,k)), k end, k
            else
                return function() return nil, nil end, k
            end
        end

        if target == pattern then return target end
        if type(pattern) == "function" then
            local v, var_name, maybe_var_proof = pattern(target)
            if maybe_var_proof == var_proof 
                    and ( type(var_name) == "string" or type(var_name) == "number" 
                        or type(var_name) == "boolean") then
                if captures[var_name] ~= nil and not deepcompare(v, captures[var_name]) then
                    return nil
                end
                captures[var_name] = v
                vars[pattern] = var_name
            end
            return v
        end
        if type(target) ~= type(pattern) then return nil end
        if type(pattern) == "table" then
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

    local matched_table = match_root_recursive(pattern, target)

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

local function eval_function_or_var(transform, captures, vars, n)
    local v, var_name, maybe_var_proof 
    if is_array(captures) then
        v, var_name, maybe_var_proof = transform(unpack(captures))
    else
        v, var_name, maybe_var_proof = transform(captures)
    end
    if maybe_var_proof == var_proof 
        and (type(var_name) == "string" 
                or type(var_name) == "number" 
                or type(var_name) == "boolean") then
        for f, name in pairs(vars) do
            if name == var_name then
                error("Possibly trying to apply an unbound variable with same name as bound variable '" .. name .. "': Make sure to use the same instance of var in the match and its transform (#" .. n .. ")")
            end
        end
        error("Trying to apply unbound variable '" .. var_name .. "'")
    end
    return v
end

local function apply_vars(t, vars)
    local res = {}
    for k, v in pairs(t) do
        local key, value = k, v
        if type(k) == "function" and vars[k] then
            key = k()
        end
        if type(v) == "table" then
            value = apply_vars(value, vars)
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
    elseif type(transform) == "function" then
        if is_empty_table(captures) then
            return transform(matched)
        else
            return eval_function_or_var(transform, captures, vars, n)
        end
    elseif is_const_transform_type[type(transform)] then
        return transform
    elseif type(transform) == "table" then
        return apply_vars(transform, vars)
    else
        error("what type of transform is this? " .. type(transform))
    end
end

local function matcher(match_pairs)
    return function(target)
        for i, match_pair in ipairs(match_pairs) do
            local matched, captures, vars = match_root(match_pair[1], target)
            if matched ~= nil then
                return apply_match(match_pair[2], matched, captures, vars, i)
            end
        end
    end
end

return {
    key = key,
    value = value,
    optional = optional,
    missing = missing,
    default_value = default_value,
    head = value,
    rest = rest_promise,
    nothing = nothing_promise,
    tail = tail_promise,
    vars = vars,
    match_root = match_root,
    match = match,
    find = find,
    match_all = match_all,
    matcher = matcher,
    matched_value = matched_value,
    as_is = as_is,
    id = id,
    is_number = is_number,
    is_string = is_string,
    is_boolean = is_boolean,
    is_function = is_function,
    is_table = is_table,
    is_array = is_array,
    is_like = is_like,
    either = either
}
