local m = require("match")
local V = m.vars()
local mm = require'mm'

local refinement = {}

local function match_refine(abbreviated_rules)

    local rules = {}
    for _, abbreviated_rule in ipairs(abbreviated_rules) do
        local rule_pattern = {}
        for _, abbreviated_var in ipairs(abbreviated_rule[1]) do
            assert(type(abbreviated_var) == "string", "Only abbreviate keys")
            rule_pattern[abbreviated_var] = V[abbreviated_var]
        end
        for k, v in pairs(abbreviated_rule) do
            if type(k) ~= "number" or k > #abbreviated_rule then
                rule_pattern[k] = v
            end
        end
        table.insert(rules, { rule_pattern, abbreviated_rule[2] })
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
            else
                projection[k] = v
            end
        end
        return projection
    end

    local function concrete_match_refine(target)
        for _, rule in ipairs(rules) do
            local pattern = rule[1]
--            local refine_plan, captures, vars = matcher(pattern, target)
            local refine_plan, initial_set = matcher(target)
            if refine_plan then
--                mm(refine_plan)
--                mm(captures)
--                mm(vars)
--                local ongoing_projection = vars
                local ongoing_projection = initial_set
                for _, transform in ipairs(refine_plan) do
                    if type(transform) == "table" then
                        local refinement_fn = transform[refinement]
                        if refinement_fn then
                            local contextualized_refinement = refinement_fn(concrete_match_refine)
                            -- maybe roll ongoing_projection here
                            ongoing_projection = contextualized_refinement(ongoing_projection)
                        else
                            ongoing_projection = project_and_roll(transform, ongoing_projection)
                        end
                    elseif type(transform) == "function" then
                        ongoing_projection = transform(ongoing_projection)
                    else
                        ongoing_projection = transform
                    end
                end
                return ongoing_projection
            end
        end
        return nil
    end

    return concrete_match_refine
end

local function refine(args)
    return {
        [refinement] = function(match_refine_fn)
            return function(args)
                return match_refine_fn(args)
            end
        end
    }
end

return {
    match_refine = match_refine,
    refine = refine
}

