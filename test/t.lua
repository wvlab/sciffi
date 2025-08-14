local fennel = require("tools.fennel")

local t = {}

--- @alias TestDiff
--- | table<any, TestDiff>
--- | {expected: any, actual: any}

--- @param actual table
--- @param expected table
--- @return TestDiff
local function diff(actual, expected)
    if type(expected) ~= "table" or type(actual) ~= "table" then
        if expected ~= actual then
            return { expected = expected, actual = actual }
        end

        return expected
    end

    --- @type TestDiff
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

--- @param actual table
--- @param expected table
--- @return nil
function t.assertdeepeql(actual, expected)
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
        error(string.format("Deep equality failed:\n%s", fennel.view(differences)))
    end
end

--- @param actual any
--- @param expected any
--- @return nil
function t.asserteql(actual, expected)
    if actual ~= expected then
        error(string.format("Expected %s, but got %s", fennel.view(expected), fennel.view(actual)))
    end
end

--- @param value any
--- @return nil
function t.assertnil(value)
    t.asserteql(nil, value)
end

--- @param value any
--- @return nil
function t.asserttrue(value)
    t.asserteql(true, value)
end

--- @param value any
--- @return nil
function t.assertfalse(value)
    t.asserteql(false, value)
end

--- @param value any
--- @return nil
function t.asserttruthy(value)
    if not value then
        error(string.format("Expected value to be truthy, got %s", fennel.view(value)))
    end
end

--- @param value any
--- @return nil
function t.assertfalsy(value)
    if value then
        error(string.format("Expected value to be falsy, got %s", fennel.view(value)))
    end
end

--- @param func any
--- @param ... any
--- @return any?
function t.asserterr(func, ...)
    local ok, err = pcall(func, ...)
    if ok then
        error(string.format(
            "Expected error, but function returned successfully"
        ))
        return
    end

    return err
end

--- @param ...string
--- @return table<string, true>
function t.tags(...)
    local r = {}
    for _, tag in pairs({ ... }) do
        r[tag] = true
    end

    return r
end

return t
