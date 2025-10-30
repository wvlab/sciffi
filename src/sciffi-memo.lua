local sciffi = require("sciffi-base")
local sha2 = require("sha2")

if sciffi.memo ~= nil then
    return
end

local errenum = sciffi.helpers.defenum(
    "writefail",
    "openfail"
)

--- @class SciFFIMemoIO
--- @field write fun(hash: string, result: string): SciFFIError?
--- @field lookup fun(hash: string): string?, SciFFIError?

--- @class SciFFIMemo
--- @field err SciFFIEnum
local memo = {
    err = errenum,
}

--- @param code string
--- @return string
function memo.hash(code)
    local result, _ = sha2.digest256(code):gsub(".", function(c)
        return ("%02x"):format(c:byte())
    end)

    return result
end

--- @param mio SciFFIMemoIO
--- @param code string
--- @param result string
--- @return SciFFIError?
function memo.write(mio, code, result)
    local hash = sciffi.memo.hash(code)
    return mio.write(hash, result)
end

--- @param mio SciFFIMemoIO
--- @param code string
--- @return string?, SciFFIError?
function memo.lookup(mio, code)
    local hash = sciffi.memo.hash(code)
    return mio.lookup(hash)
end

sciffi.memo = memo

return memo
