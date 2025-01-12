-- TODO: add types
-- TODO: check for shell escape
-- TODO: add lua lsp config
-- TODO: add message and warning API
sciffi = {
    interpretators = {},
    output = "",

    write = function(text)
        sciffi.output = sciffi.output .. text
    end,

    flush = function()
        local output, _ = sciffi.output:gsub("\n", " ")
        tex.print(
            luatexbase.catcodetables["sciffi@savedtable"],
            output
        )

        sciffi.output = ""
    end,

    helpers = {
        -- TODO: test somehow????
        deindent = function(code)
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
        end,
    }
}
return sciffi
