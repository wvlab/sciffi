local sciffi = require("sciffi-base")
local memo = require("sciffi-memo")

--- @class SciFFIMemoFSIO : SciFFIMemoIO
memo.io.fs = {}

function memo.io.fs.path(hash)
    return ("_sciffi/%s"):format(hash)
end

function memo.io.fs.resultpath(hash)
    return ("_sciffi/%s/result"):format(hash)
end

function memo.io.fs.write(hash, result)
    -- TODO: handle mkdir fails
    lfs.mkdir("_sciffi")
    lfs.mkdir(memo.io.fs.path(hash))
    sciffi.helpers.log("warning", "I AM HERE BLYAT")
    local path = memo.io.fs.resultpath(hash)
    local file = io.open(path, "w")
    if not file then
        return sciffi.err.new(
            memo.err.writefail,
            sciffi.err.format,
            { path = path }
        )
    end

    file:write(result)
    file:close()
    return nil
end

function memo.io.fs.lookup(hash)
    local rpath = memo.io.fs.resultpath(hash)
    if not lfs.isfound(rpath) then
        return nil, nil
    end

    local file = io.open(rpath, "r")
    if not file then
        return nil, sciffi.err.new(
            sciffi.memo.err.openfail,
            sciffi.err.format,
            { hash = hash }
        )
    end

    local result = file:read("*a")
    file:close()
    return result, nil
end

return memo.io.fs
