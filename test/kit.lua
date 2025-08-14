local kit = {
    tests = {}
}

function kit:modules(modules)
    for _, mod in pairs(modules) do
        local tests = require(mod)
        for _, k in pairs(tests) do
            kit:register(k.name, k.tags, k.test)
        end
    end

    return kit
end

function kit:register(name, _tags, f)
    kit.tests[name] = f
end

function kit:run()
    local success = 0
    local failed = 0

    for name, test in pairs(kit.tests) do
        local status, err = pcall(test)

        if status then
            success = success + 1
            print(string.format("test %s passed", name))
        else
            failed = failed + 1
            print(string.format("test %s failed, reason: %s", name, err))
        end
    end

    print(string.format(
        "total %d, successful %d, failed %d",
        success + failed, success, failed
    ))

    return failed == 0
end

return kit:modules({
    "test.helpers.deindent"
}):run()
