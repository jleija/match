local m = require("match")

local refinement = {}

local var_key = {}
local vars = {}

local vars_mt = {}

vars_mt.__index = function(t, k)
    assert(type(k) == "string", debug.traceback())
    if rawget(t, var_key) then
        t.subkeys = rawget(t, 'subkeys') or {}
        table.insert(t.subkeys, k)
        return t
    end
    local var_proxy = {
        [var_key] = k
    }
    setmetatable(var_proxy, vars_mt)
    return var_proxy
end

setmetatable(vars, vars_mt)

local function recurse_refine() end

local function match_refine(rules)
    local refine_vars = m.namespace().vars
    local matcher = m.matcher(rules)

    local function project_and_roll(project_set, input_set)
        local projection = {}
        if type(input_set) == "table" then
            for k,v in pairs(input_set) do
                if not project_set[k] then
                    projection[k] = v
                end
            end
        end
        for k, v in pairs(project_set) do
            if type(v) == "function" then
                projection[k] = v(input_set)
--            elseif m.is_var(v) then
--                assert(v.value ~= m.unbound, "Unbound variable '" 
--                                        .. v.name[var_key]
--                                        .. "' in projection")
--                projection[k] = v.value
            elseif type(v) == "table" and rawget(v, var_key) then
                local refine_var = refine_vars[v[var_key]]
                assert(refine_var, "Variable " .. v[var_key] .. " not set for projection")
--                local value = refine_var() 
                local value = refine_var.value ~= m.unbound and refine_var.value
                                or project_set[v[var_key]] 
                                or input_set[v[var_key]] 
                assert(value ~= nil, "No value matched for variable " .. v[var_key])

                if rawget(v, 'subkeys') then
                    for _, k in ipairs(v.subkeys) do
                        assert(type(value) == "table", 
                                        "Unexpected value of type "
                                        .. type(value) 
                                        .. " while trying to subkey with '" 
                                        .. k .. "'")
                        local subvalue = value[k]
                        assert(subvalue ~= nil,
                                "Variable " .. v[var_key] ..
                                " does not have expected path/subkeys ." ..
                                table.concat(v.subkeys, ".") ..
                                " failed at expected subkey " .. k)
                        value = subvalue
                    end
                end

                projection[k] = value
            else
                projection[k] = v
            end
        end
        return projection
    end

    local function project_and_roll_tables(maybe_project_set, input_set)
        if type(maybe_project_set) == "table" then
            return project_and_roll(maybe_project_set, input_set)
        else
            return maybe_project_set
        end
    end

    local function match_refine_for_given_rules(target)
        -- TODO: make sure to use the same namespace for variables
        --       - use bound_vars to do the prqjections
        local refine_plan, matched_set, bound_vars, rule_n = matcher(target)
        if matched_set then
            if not m.is_array(refine_plan) then
                return refine_plan
            end
            local ongoing_projection = target
            for refine_n, refine in ipairs(refine_plan) do
                if m.is_var(refine) then
                    ongoing_projection[refine.name] = refine.value
                elseif type(refine) == "table" then
                    ongoing_projection = project_and_roll(refine, ongoing_projection)
                elseif type(refine) == "function" then
                    if refine == recurse_refine then
                        ongoing_projection = project_and_roll_tables(
                                match_refine_for_given_rules(ongoing_projection), 
                                ongoing_projection)
                    else
                        local status, res_or_err = pcall(function()
                                    return refine(ongoing_projection)
                                end)

                        if not status then
                            error("match_refine " 
                                    .. (rules.name or "unknown")
                                    .. ", rule "
                                    .. (rules[rule_n].name or rule_n)
                                    .. ", refine "
                                    .. refine_n
                                    .. ": " 
                                    .. res_or_err)
                        else
                            ongoing_projection = project_and_roll_tables(
                                    res_or_err,
                                    ongoing_projection)
                        end
                    end
                else
                    ongoing_projection = refine
                end
            end
            return ongoing_projection
        end
        return nil
    end

    return match_refine_for_given_rules, refine_vars
end

return {
    match_refine = match_refine,
    refine = recurse_refine,
    vars = vars
}

