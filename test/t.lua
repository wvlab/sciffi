local fennel = require("tools.fennel")

local t = {}

local function diff(expected, actual)
    if type(expected) ~= "table" or type(actual) ~= "table" then
        if expected ~= actual then
            return { expected = expected, actual = actual }
        else
            return expected
        end
    end

    local out = {}
    for k, v in pairs(expected) do
        if actual[k] == nil then
            out[k] = { expected = v, actual = "<missing>" }
        else
            out[k] = diff(v, actual[k])
        end
    end

    for k, v in pairs(actual) do
        if expected[k] == nil then
            out[k] = { expected = "<missing>", actual = v }
        end
    end
    return out
end

function t.assertdeepeql(expected, actual)
    local function deepeq(a, b)
        if type(a) ~= type(b) then
            return false
        end

        if type(a) ~= "table" then
            return a == b
        end

        for k, v in pairs(a) do
            if not deepeq(v, b[k]) then
                return false
            end
        end

        for k, v in pairs(b) do
            if not deepeq(v, a[k]) then
                return false
            end
        end

        return true
    end

    if not deepeq(expected, actual) then
        local differences = diff(expected, actual)
        error("Deep equality failed:\n" .. fennel.view(differences), 2)
    end
end

-- function t.assertdeepeql(v1, v2)
--     local typev1 = type(v1)
--     local typev2 = type(v2)
--     if typev1 ~= typev2 then
--         error(string.format(
--             "Expected %s (%s) and %s (%s) to have equal types",
--             fennel.view(v1), typev1,
--             fennel.view(v2), typev2
--         ))
--     end
--
--     if typev1 ~= "table" then
--         t.asserteql(v1, v2)
--     end
--
--     -- TODO what?
-- end
--
function t.asserteql(v1, v2)
    if v1 ~= v2 then
        error(string.format("Expected %s, but got %s", fennel.view(v1), fennel.view(v2)))
    end
end

function t.assertnil(value)
    t.asserteql(nil, value)
end

function t.asserttrue(value)
    t.asserteql(true, value)
end

function t.assertfalse(value)
    t.asserteql(false, value)
end

function t.asserttruthy(value)
    if not value then
        error(string.format("Expected value to be truthy, got %s", fennel.view(value)))
    end
end

function t.assertfalsy(value)
    if value then
        error(string.format("Expected value to be falsy, got %s", fennel.view(value)))
    end
end

function t.asserterr(func, ...)
    local ok, err = pcall(func, ...)
    if ok then
        error(string.format(
            "Expected error, but function returned successfully"
        ))
    end

    return err
end

return t
