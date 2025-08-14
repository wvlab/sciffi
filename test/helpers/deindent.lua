local base = require("sciffi-base")
local t = require("test.t")

return {
    {
        name = "deindent removes uniform leading indentation",
        tags = t.tags("helpers", "helpers-deindent"),
        test = function()
            local code = base.helpers.deindent("    one\n    two\n    three")
            t.asserteql(code, "one\ntwo\nthree")
        end
    },
    {
        name = "deindent trims surrounding blank lines",
        tags = t.tags("helpers", "helpers-deindent"),
        test = function()
            local code = base.helpers.deindent("\n\n    line1\n    line2\n\n")
            t.asserteql(code, "line1\nline2")
        end
    },
    {
        name = "deindent handles mixed indentation levels",
        tags = t.tags("helpers", "helpers-deindent"),
        test = function()
            local code = base.helpers.deindent("        line1\n          line2\n        line3")
            t.asserteql(code, "line1\n  line2\nline3")
        end
    },
    {
        name = "deindent with no indentation",
        tags = t.tags("helpers", "helpers-deindent"),
        test = function()
            local code = base.helpers.deindent("one\ntwo\nthree")
            t.asserteql(code, "one\ntwo\nthree")
        end
    },
    {
        name = "deindent handles single line input",
        tags = t.tags("helpers", "helpers-deindent"),
        test = function()
            local code = base.helpers.deindent("    only one line")
            t.asserteql(code, "only one line")
        end
    },
    {
        name = "deindent handles empty string",
        tags = t.tags("helpers", "helpers-deindent"),
        test = function()
            local code = base.helpers.deindent("")
            t.asserteql(code, "")
        end
    },
    {
        name = "deindent handles all blank lines",
        tags = t.tags("helpers", "helpers-deindent"),
        test = function()
            local code = base.helpers.deindent("\n\n\n    \n\n")
            t.asserteql(code, "")
        end
    },
    {
        name = "deindent handles empty newlines",
        tags = t.tags("helpers", "helpers-deindent"),
        test = function()
            local code = base.helpers.deindent("    line1\n    line2\n\n    line3\n")
            t.asserteql(code, "line1\nline2\n\nline3")
        end
    }
}
