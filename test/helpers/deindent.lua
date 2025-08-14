local base = require("sciffi-base")

return {
    {
        name = "deindent removes uniform leading indentation",
        tags = {},
        test = function()
            local code = base.helpers.deindent("    one\n    two\n    three")
            assert(code == "one\ntwo\nthree", "Uniform indent should be removed")
        end
    },
    {
        name = "deindent trims surrounding blank lines",
        tags = {},
        test = function()
            local code = base.helpers.deindent("\n\n    line1\n    line2\n\n")
            assert(code == "line1\nline2", "Should trim leading/trailing blank lines")
        end
    },
    {
        name = "deindent handles mixed indentation levels",
        tags = {},
        test = function()
            local code = base.helpers.deindent("        line1\n          line2\n        line3")
            assert(code == "line1\n  line2\nline3", "Should preserve relative indentation")
        end
    },
    {
        name = "deindent with no indentation",
        tags = {},
        test = function()
            local code = base.helpers.deindent("one\ntwo\nthree")
            assert(code == "one\ntwo\nthree", "Should not change code with no indentation")
        end
    },
    {
        name = "deindent handles single line input",
        tags = {},
        test = function()
            local code = base.helpers.deindent("    only one line")
            assert(code == "only one line", "Should strip indent on a single line")
        end
    },
    {
        name = "deindent handles empty string",
        tags = {},
        test = function()
            local code = base.helpers.deindent("")
            assert(code == "", "Empty input should return empty")
        end
    },
    {
        name = "deindent handles all blank lines",
        tags = {},
        test = function()
            local code = base.helpers.deindent("\n\n\n    \n\n")
            assert(code == "", "Only blank lines should result in empty string")
        end
    },
    {
        name = "deindent handles empty newlines",
        tags = {},
        test = function()
            local code = base.helpers.deindent("    line1\n    line2\n\n    line3\n")

            assert(
                code == "line1\nline2\n\nline3",
                "Should remove common indent and preserve blank lines"
            )
        end
    }
}
