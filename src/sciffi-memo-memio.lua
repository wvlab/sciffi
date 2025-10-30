local memo = require("sciffi-memo")

--- @class SciFFIMemoMemIO : SciFFIMemoIO
--- @field store table<string, string>
memo.io.mem = {
    store = {},
}

--- @param hash string
--- @param result string
--- @return nil
function memo.io.mem.write(hash, result)
    memo.io.mem.store[hash] = result
    return nil
end

--- @param hash string
--- @return string
--- @return nil
function memo.io.mem.lookup(hash)
    return memo.io.mem.store[hash], nil
end

return memo.io.mem
