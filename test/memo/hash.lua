local memo = require("sciffi-memo")
local t = require("test.t")

return {
    {
        name = "hash generates deterministic hash",
        tags = t.tags("memo", "memo-hash"),
        test = function()
            local code = "print('hello world')"
            t.asserttruthy(
                memo.hash(code) == memo.hash(code)
            )
        end
    },
    {
        name = "hash is composed of ascii alphabet and numbers",
        tags = t.tags("memo", "memo-hash"),
        test = function()
            local code = "print('O(N) notation')"
            local hash = memo.hash(code)

            for c in hash:gmatch(".") do
                t.asserttruthy(c:match("%w"))
            end
        end
    },
}
