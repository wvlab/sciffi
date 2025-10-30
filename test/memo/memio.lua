local memo = require("sciffi-memo")
local memio = require("sciffi-memo-memio")
local t = require("test.t")

return {
    {
        name = "write stores result in memio",
        tags = t.tags("memo", "memo-io", "memo-io-memio", "memo-io-write"),
        test = function()
            local code = "print('mock test')"
            local result = "output"
            memo.write(memio, code, result)

            t.asserteql(memo.lookup(memio, code), result)
        end
    },
    {
        name = "check returns nil for missing code",
        tags = t.tags("memo", "memo-io", "memo-io-memio", "memo-io-lookup"),
        test = function()
            local missing, _ = memo.lookup(memio, "print('nothing here')")
            t.assertnil(missing)
        end
    },
}
