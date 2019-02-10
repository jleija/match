local function is_empty_table(a)
    for _, _ in pairs(a) do
        return false
    end
    return true
end

local function is_array(t)
    return t[1] or is_empty_table(t)
end

local function value(v) return v end
local function key(k) return k end
local function rest(t, k)
    assert(is_array(t), "rest can be applied only to arrays")
    assert(type(k) == "number", "Invalid key: '" .. k .. "' of type " .. type(k))
    local res = {}
    for i=k,#t do
        table.insert(res, t[i])
    end
    return res
end

local function match_empties(a, b)
    if is_empty_table(a) and is_empty_table(b) then
        return {}
    end
end

local function match(a, b)
    local function key_in_table(t, k, v)
        if k == key then
            return function(t, key_fn, value)
                for k, v in pairs(t) do
                    local res = match(t[k], value)
                    if res then return res, k end
                end
                return nil
            end, k
        end
        if v == rest and is_array(t) then
            return function(t, key, value)
                return rest(t, k), k
            end, k
        end
        if t[k] then 
            return function(t, k, v) return match(t[k], v), k end, k
        else
            return function() return nil, nil end, k
        end
    end

    if a == b then return b end
    if type(b) == "function" then
        return b(a)
    end
    if type(a) ~= type(b) then return nil end
    if type(b) == "table" then
        local res = match_empties(a, b) 
        if res then return res end

        local matches = {}
        local did_match = true
        local at_least_one = false
        for k, v in pairs(b) do
            local matcher, key = key_in_table(a, k, v)
            if key then
                local match_result, matched_k = matcher(a, key, v)
                if match_result then
                    matches[matched_k] = match_result
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

local function match_anywhere(a, b, visited)
    local res = match(a, b)
    if res then return res end

    if type(a) == "table" then
        visited = visited or {}
        visited[a] = true
        for k, v in pairs(a) do
            if type(v) == "table" then
                if not visited[v] then
                    local res = match_anywhere(v, b, visited)
                    if res then return res end
                end
            end
        end
    end
    return nil
end

return {
    key = key,
    value = value,
    rest = rest,
    match = match,
    match_anywhere = match_anywhere
}
