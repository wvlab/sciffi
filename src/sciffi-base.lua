-- TODO: check for shell escape
-- TODO: add message and warning API

-- FOR SOME REASON UNKNOWN TO ME THEY FORBID TO CALL `callback.register`
-- this trick ensures this function will be present
if luatexbase then
    local _luatexbase = luatexbase
    luatexbase.uninstall()
    luatexbase = _luatexbase
end

--- @class Interpretator
--- @field execute fun(code: string): nil

--- @class (exact) SciFFI
--- @field interpretators { [string]: Interpretator }
--- @field helpers Helpers
--- @field env SciFFIEnv
--- @field private output string
--- @field public write fun(text: string): nil
--- @field private flush fun(): nil
sciffi = {
    interpretators = {},
    output = "",
}

--- @param text string
--- @return nil
function sciffi.write(text)
    sciffi.output = sciffi.output .. text
end

--- @return nil
function sciffi.flush()
    local output, _ = sciffi.output:gsub("\n", " ")
    tex.print(luatexbase.catcodetables["sciffi@savedtable"], output)

    sciffi.output = ""
end

--- @class SciFFIEnv
--- @field lines string[]
--- @field private interpretator string
--- @field private previous_callback function | nil
--- @field private callback fun(line: string): string | nil
--- @field private start fun(interpretator: string): nil
--- @field private close fun(): nil
sciffi.env = {
    lines = {}
}

--- @param interpretator string
--- @return nil
function sciffi.env.start(interpretator)
    if not sciffi.interpretators[interpretator] then
        -- TODO: add error printing with future api
        return
    end
    sciffi.env.interpretator = interpretator
    sciffi.env.previous_callback = callback.find("process_input_buffer")
    local _, err = callback.register("process_input_buffer", sciffi.env.callback)
    if err then
        -- TODO: add error printing with future api
        texio.write_nl("con", err)
        sciffi.env.close()
        return
    end
end

--- @param line string
--- @return string | nil
function sciffi.env.callback(line)
    local pos = line:find("\\end{sciffi}")
    if not pos then
        table.insert(sciffi.env.lines, line)
        return ""
    end
    local before = line:sub(1, pos - 1)
    local after = line:sub(pos)

    table.insert(sciffi.env.lines, before)
    return after
end

--- @return nil
function sciffi.env.close()
    local _, err = callback.register("process_input_buffer", sciffi.env.previous_callback)
    if err then
        -- TODO: add error printing with future api
        return
    end

    callback.previous_callback = nil
    sciffi.interpretators[sciffi.env.interpretator].execute(table.concat(sciffi.env.lines, "\n"))
    sciffi.flush()
end

--- @class (exact) Helpers
--- @field deindent fun(code: string): string
sciffi.helpers = {}

--- @param code string
--- @return string
function sciffi.helpers.deindent(code)
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

return sciffi
