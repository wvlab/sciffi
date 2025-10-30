--- @class TestCase
--- @field name string
--- @field tags [string]
--- @field test fun(): any

--- @class TestKit
--- @field private tests table<string, TestCase>
--- @field private tags table<string, true>
local kit = {
    tests = {},
    tags = {}
}

--- @param modules [string]
--- @return TestKit
--- Register all test case
function kit:modules(modules)
    for _, mod in pairs(modules) do
        local tests = require(mod)
        for _, test in pairs(tests) do
            kit:case(test)
        end
    end

    return kit
end

--- @param test TestCase
--- Register the test case
function kit:case(test)
    kit.tests[test.name] = test
end

--- @class (exact) TestKitOpts
--- @field only string? only run tests with this tag
--- @field ignore table<string, boolean> ignore this tags

--- @param test TestCase
--- @param opts TestKitOpts
--- @return boolean
local function shouldrun(test, opts)
    if opts.only and not test.tags[opts.only] then
        return false
    end

    for ignore, ok in pairs(opts.ignore) do
        if ok and test.tags[ignore] then
            return false
        end
    end

    return true
end

--- @param opts TestKitOpts
--- @return boolean
function kit:run(opts)
    local success = 0
    local failed = 0

    for name, test in pairs(kit.tests) do
        if shouldrun(test, opts) then
            -- TODO: extract
            local status, err = pcall(test.test)

            if status then
                success = success + 1
                print(string.format("test %s passed", name))
            else
                failed = failed + 1
                print(string.format(
                    "\ntest %s failed, reason:\n %s\n",
                    name, err
                ))
            end
        end
    end

    print(string.format(
        "total %d, successful %d, failed %d",
        success + failed, success, failed
    ))

    return failed == 0
end

return kit:modules({
    "test.helpers.deindent",
    "test.portals.cosmo.proto",
    "test.portals.cosmo.usage",
    "test.err.usage",
    "test.memo.hash",
    "test.memo.memio"
})
