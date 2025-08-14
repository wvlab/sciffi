--- @class TestCase
--- @field name string
--- @field tags [string]
--- @field func fun(): any

--- @class TestKit
--- @field private tests table<string, TestCase>
local kit = {
    tests = {}
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


--- @class TestKitOpts

--- @param opts TestKitOpts
--- @return boolean
function kit:run(opts)
    local success = 0
    local failed = 0

    for name, test in pairs(kit.tests) do
        local status, err = pcall(test.func())

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

    print(string.format(
        "total %d, successful %d, failed %d",
        success + failed, success, failed
    ))

    return failed == 0
end

return kit:modules({
    "test.helpers.deindent",
    "test.portals.cosmo.proto",
})
