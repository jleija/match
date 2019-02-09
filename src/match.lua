local function is_empty_table(a)
    for _, _ in pairs(a) do
        return false
    end
    return true
end

local function value(v) return v end

local function match_empties(a, b)
    if is_empty_table(a) and is_empty_table(b) then
        return {}
    end
end

local function match(a, b)
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
            if a[k] then
                local match_result = match(a[k], v) 
                if match_result then
                    matches[k] = match_result
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
    value = value,
    match = match,
    match_anywhere = match_anywhere
}
