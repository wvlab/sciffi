--- @class SciFFIMemoMemIO : SciFFIMemoIO
--- @field store table<string, string>
local memio = {
    store = {},
}

--- @param hash string
--- @param result string
--- @return nil
function memio.write(hash, result)
    memio.store[hash] = result
    return nil
end

--- @param hash string
--- @return string
--- @return nil
function memio.lookup(hash)
    return memio.store[hash], nil
end

return memio
