local m = require("match")

local refinement = {}

local var_key = {}
local vars = {}

local mt = {
    __index = function(t, k)
        return {
            [var_key] = k
        }
    end
}

setmetatable(vars, mt)

local function refine() end

local function match_refine(abbreviated_rules)
    local refine_vars = m.vars()
    local rules = {}
    for _, abbreviated_rule in ipairs(abbreviated_rules) do
        local rule_pattern = {}
        local pattern = abbreviated_rule[1]
        if m.is_array(pattern) then
            for _, abbreviated_var in ipairs(pattern) do
                assert(type(abbreviated_var) == "string", "Only abbreviate string/named keys")
                rule_pattern[abbreviated_var] = refine_vars[abbreviated_var]
            end
            for k, v in pairs(pattern) do
                if type(k) ~= "number" or k > #pattern then
                    rule_pattern[k] = v
                end
            end
            table.insert(rules, { rule_pattern, abbreviated_rule[2] })
        else
            table.insert(rules, abbreviated_rule)
        end
    end
    local matcher = m.matcher(rules)

    local function project_and_roll(project_set, input_set)
        local projection = {}
        for k,v in pairs(input_set) do
            if not project_set[k] then
                projection[k] = v
            end
        end
        for k, v in pairs(project_set) do
            if type(v) == "function" then
                projection[k] = v(input_set)
            elseif type(v) == "table" and rawget(v, var_key) then
                local refine_var = refine_vars[v[var_key]]
                assert(refine_var, "Variable " .. v[var_key] .. " not set for projection")
                projection[k] = refine_var()
            else
                projection[k] = v
            end
        end
        return projection
    end

    local function match_refine_for_given_rules(target)
        for _, rule in ipairs(rules) do
            local pattern = rule[1]
            local refine_plan, initial_set = matcher(target)
            if refine_plan then
                if not m.is_array(refine_plan) then
                    return refine_plan
                end
                local ongoing_projection = initial_set
                for _, transform in ipairs(refine_plan) do
                    if type(transform) == "table" then
                        ongoing_projection = project_and_roll(transform, ongoing_projection)
                    elseif type(transform) == "function" then
                        if transform == refine then
                            -- maybe roll ongoing_projection here
                            ongoing_projection = match_refine_for_given_rules(ongoing_projection)
                        else
                            ongoing_projection = transform(ongoing_projection)
                        end
                    else
                        ongoing_projection = transform
                    end
                end
                return ongoing_projection
            end
        end
        return nil
    end

    return match_refine_for_given_rules, refine_vars
end

return {
    match_refine = match_refine,
    refine = refine,
    vars = vars
}

