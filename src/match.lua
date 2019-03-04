local function is_empty_table(t)
    for _, _ in pairs(t) do
        return false
    end
    return true
end

local function is_array(t)
    return t[1] or is_empty_table(t)
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
        if not present[ik] then
            res[ik] = iv
        end
    end
    return res
end

local function match_empties(a, b)
    if is_empty_table(a) and is_empty_table(b) then
        return {}
    end
end

local function match_root( pattern, target)
    local function key_in_table(t, k, v)
        if k == key then
            return function(t, key_fn, value)
                for k, v in pairs(t) do
                    local res = match_root( value, t[k])
                    if res then return res, k end
                end
                return nil
            end, k
        end
        if v == tail and is_array(t) then
            return function(t, key, value)
                return tail(t, k), k
            end, k
        end
        if v == rest then
            return function(t, key, value)
                return rest(t, pattern), k, true        -- splat
            end, k
        end
        if t[k] then 
            return function(t, k, v) return match_root( v, t[k]), k end, k
        else
            return function() return nil, nil end, k
        end
    end

    if target == pattern then return pattern end
--    if type(pattern) == "function" then
--    if pattern == value then
--        return pattern(target)
--    end
    if type(pattern) == "function" then
        return pattern(target)
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
                if match_result then
                    if splat then
                        for k, v in pairs(match_result) do
                            matches[k] = v
                        end
                    else
                        matches[matched_k] = match_result
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

local function match(pattern, target, visited)
    local res = match_root( pattern, target)
    if res then return res end

    if type(target) == "table" then
        visited = visited or {}
        visited[target] = true
        for k, v in pairs(target) do
            if type(v) == "table" then
                if not visited[v] then
                    local res = match( pattern, v, visited)
                    if res then return res end
                end
            end
        end
    end
    return nil
end

local function match_all(pattern, target, visited)
    local res = match_root( pattern, target)
    if res then return res end

    if type(target) == "table" then
        local matched = {}
        visited = visited or {}
        visited[target] = true
        for k, v in pairs(target) do
            if type(v) == "table" then
                if not visited[v] then
                    local res = match(pattern, v, visited)
                    if res then table.insert(matched, res) end
                end
            end
        end
        return matched
    end
    return {}
end

return {
    key = key,
    value = value,
    head = value,
    rest = rest,
    tail = tail,
    match_root = match_root,
    match = match,
    match_all = match_all
}
