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
    end
}
return sciffi
