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
--- @field io table<string, SciFFIMemoIO>
local memo = {
    err = errenum,
    io = {},
}

--- @param code string
--- @return string
function memo.hash(code)
    local result, _ = sha2.digest256(code):gsub(".", function(c)
        return ("%02x"):format(c:byte())
    end)

    return result
end

--- @param path string
--- @return string, SciFFIError?
function memo.hashfile(path)
    local file = io.open(path)
    if not file then
        return "", sciffi.err.new(
            sciffi.memo.err.openfail,
            sciffi.err.format,
            { path = path }
        )
    end

    local code = file:read("*a")
    file:close()

    return memo.hash(code)
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
--- @param path string
--- @param result string
--- @return SciFFIError?
function memo.writefile(mio, path, result)
    local hash = sciffi.memo.hashfile(path)
    return mio.write(hash, result)
end

--- @param mio SciFFIMemoIO
--- @param code string
--- @return string?, SciFFIError?
function memo.lookup(mio, code)
    local hash = sciffi.memo.hash(code)
    return mio.lookup(hash)
end

function memo.lookupfile(mio, path)
    local hash = sciffi.memo.hashfile(path)
    return mio.lookup(hash)
end

sciffi.memo = memo

return memo
