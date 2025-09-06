require("sciffi-base")

--- @class PythonInterpretator : Interpretator
sciffi.interpretators.python = {}

function sciffi.interpretators.python.execute_snippet(code, options)
    local filepath, err = sciffi.helpers.save_snippet(sciffi.helpers.deindent(code), ".py")
    if err then
        --- @cast filepath string
        sciffi.helpers.log("error", err:format())
        return
    end
    sciffi.interpretators.python.execute_script(filepath, options)
end

function sciffi.interpretators.python.execute_script(filepath, options)
    local opts = sciffi.helpers.parse_options(options)

    local portal, setuperr
    if opts.portal == "cosmo" and sciffi.portals.cosmo == nil then
        sciffi.helpers.log("warning", "Cosmo portal isn't loaded, defaulting to simple")
        opts.portal = "simple"
    end

    if opts.portal == "cosmo" then
        portal, setuperr = sciffi.portals.cosmo.setup({
            interpretator = "python",
            command = "python",
            args = { filepath },
        })
    else
        portal, setuperr = sciffi.portals.simple.setup({
            interpretator = "python",
            filepath = filepath,
            command = "python"
        })
    end

    if setuperr then
        sciffi.helpers.log("error", setuperr)
        return
    end

    local result, perr = portal:launch()
    if perr then
        sciffi.helpers.log("error", perr:format())
        return
    end

    local rerr = sciffi.helpers.handle_portal_result(result)
    if rerr then
        sciffi.helpers.log("error", rerr:format())
        return
    end
end

return sciffi.interpretators.python
