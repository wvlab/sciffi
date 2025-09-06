local sciffi = require("sciffi-base")
local t = require("test.t")

local errenum = sciffi.helpers.defenum("foo")

return {
    {
        name = "sciffierr new uses default format when format is nil",
        tags = t.tags("err"),
        test = function()
            local err = sciffi.err.new(errenum.foo, nil, nil)
            local formatted = err:format()

            t.asserteql(formatted, "foo")
        end
    },
    {
        name = "sciffierr new uses custom format function",
        tags = t.tags("err"),
        test = function()
            local function fmterr(self)
                return ("Custom error with tag %s and data %s"):format(self.tag.value, self.data.value)
            end

            local err = sciffi.err.new(errenum.foo, fmterr, { value = "test-data" })
            local formatted = err:format()

            t.asserteql(formatted, "Custom error with tag foo and data test-data")
        end
    },
    {
        name = "sciffierr new handles missing debug info",
        tags = t.tags("err"),
        test = function()
            local original_debug = debug
            debug = nil

            local err = sciffi.err.new(errenum.foo, nil, nil)

            t.asserteql(err.tag, errenum.foo)
            t.asserteql(err.src, "?")
            t.asserteql(err.fnline, -1)
            t.asserteql(err.line, -1)

            debug = original_debug
        end
    },
    {
        name = "sciffierr new captures valid debug info",
        tags = t.tags("err"),
        test = function()
            local function aux()
                return sciffi.err.new(errenum.foo, nil, nil)
            end

            local err = aux()
            t.asserteql(err.tag, errenum.foo)
            t.asserttruthy(err.src:find("usage.lua") or err.src:find("test/err/usage.lua"))
            t.asserttruthy(err.fnline > 0)
            t.asserttruthy(err.line > 0)
        end
    },
}
