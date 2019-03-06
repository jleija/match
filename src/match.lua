local function is_empty_table(t)
    for _, _ in pairs(t) do
        return false
    end
    return true
end

local function is_array(t)
    return t[1] or is_empty_table(t)
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

local function value(v) return v end
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

local function var(var_name)
    local bound_value
    return function(value)
        if value == nil then
            return bound_value, var_name
        end
--        if bound_value == nil then    -- sticky bound of updatable?
            bound_value = value
--        end
        return value, var_name
    end
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
    local function match_root_recursive( pattern, target)
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
            if t[k] then 
                return function(t, k, v) return match_root_recursive( v, t[k]), k end, k
            else
                return function() return nil, nil end, k
            end
        end

        if target == pattern then return pattern end
        if type(pattern) == "function" then
            local v, var = pattern(target)
            if var then
                if captures[var] and not deepcompare(v, captures[var]) then
                    return nil
                end
                captures[var] = v
--                if v ~= pattern() then -- fail on diff sticky bounded value?
--                    return nil
--                end
                vars[pattern] = var
            end
            return v
        end
        if type(target) ~= type(pattern) then return nil end
        if type(pattern) == "table" then
            local res = match_empties( pattern, target) 
            if res then return res end

            local matches = {}
            local did_match = true
            local at_least_one = false
            for k, v in pairs(pattern) do
                local matcher, key = key_in_table(target, k, v)
                if key then
                    local match_result, matched_k, splat = matcher(target, key, v)
                    if match_result ~= nil then
                        if splat then
                            for k, v in pairs(match_result) do
                                matches[k] = v
                            end
                        else
                            if not second_pass or match_result ~= nothing then
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

return {
    key = key,
    value = value,
    head = value,
    rest = rest_promise,
    nothing = nothing_promise,
    tail = tail_promise,
    var = var,
    match_root = match_root,
    match = match,
    match_all = match_all
}
