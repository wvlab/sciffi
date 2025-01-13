-- TODO: check for shell escape
-- TODO: add message and warning API

--- @class Interpretator
--- @field execute fun(code: string): nil

--- @class (exact) SciFFI
--- @field interpretators Interpretator[]
--- @field helpers Helpers
--- @field private output string
--- @field public write fun(text: string): nil
--- @field private flush fun(): nil
sciffi = {
    interpretators = {},
    output = "",
}

function sciffi.write(text)
    sciffi.output = sciffi.output .. text
end

function sciffi.flush()
    local output, _ = sciffi.output:gsub("\n", " ")
    tex.print(
        luatexbase.catcodetables["sciffi@savedtable"],
        output
    )

    sciffi.output = ""
end

--- @class Helpers
--- @field deindent fun(code: string): string
local helpers = {}
function helpers.deindent(code)
    code = code:match("^\n*(.-)\n*$")

    local min_indent = math.huge
    for line in code:gmatch("[^\n]+") do
        local leading_spaces = line:match("^(%s*)")
        if #line > 0 then
            min_indent = math.min(min_indent, #leading_spaces)
        end
    end

    local result = code:gsub("([^\n]+)", function(line)
        return line:sub(min_indent + 1)
    end)

    return result
end

sciffi.helpers = helpers

return sciffi
