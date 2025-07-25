local base = require("sciffi-base")

local kit = {
    tests = {}
}

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

kit:register("deindent removes uniform leading indentation", {}, function()
    local code = base.helpers.deindent("    one\n    two\n    three")
    assert(code == "one\ntwo\nthree", "Uniform indent should be removed")
end)

kit:register("deindent trims surrounding blank lines", {}, function()
    local code = base.helpers.deindent("\n\n    line1\n    line2\n\n")
    assert(code == "line1\nline2", "Should trim leading/trailing blank lines")
end)

kit:register("deindent handles mixed indentation levels", {}, function()
    local code = base.helpers.deindent("        line1\n          line2\n        line3")
    assert(code == "line1\n  line2\nline3", "Should preserve relative indentation")
end)

kit:register("deindent with no indentation", {}, function()
    local code = base.helpers.deindent("one\ntwo\nthree")
    assert(code == "one\ntwo\nthree", "Should not change code with no indentation")
end)

kit:register("deindent handles single line input", {}, function()
    local code = base.helpers.deindent("    only one line")
    assert(code == "only one line", "Should strip indent on a single line")
end)

kit:register("deindent handles empty string", {}, function()
    local code = base.helpers.deindent("")
    assert(code == "", "Empty input should return empty")
end)

kit:register("deindent handles all blank lines", {}, function()
    local code = base.helpers.deindent("\n\n\n    \n\n")
    assert(code == "", "Only blank lines should result in empty string")
end)

kit:register("deindent handles empty newlines", {}, function()
    local code = base.helpers.deindent("    line1\n    line2\n\n    line3\n")

    assert(
        code == "line1\nline2\n\nline3",
        "Should remove common indent and preserve blank lines"
    )
end)

return kit:run()
