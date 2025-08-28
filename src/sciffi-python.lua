require("sciffi-base")

local interpretator = {}

function interpretator.execute_snippet(code, options)
    local filepath, err = sciffi.helpers.save_snippet(sciffi.helpers.deindent(code), ".py")
    if err then
        sciffi.helpers.log("error", err:format())
        return
    end
    sciffi.interpretators.python.execute_script(filepath, options)
end

function interpretator.execute_script(filepath, options)
    local opts = sciffi.helpers.parse_options(options)

    local portalmod = sciffi.portals.simple
    if opts.portal == "cosmo" and sciffi.portals.cosmo ~= nil then
        portalmod = sciffi.portals.cosmo
    end

    local portal, err = portalmod.setup({
        interpretator = "python",
        filepath = filepath,
        command = "python"
    })

    if err ~= nil then
        sciffi.helpers.log("error", err:format())
        return
    end

    local result, perr = portal:launch()
    if perr ~= nil then
        sciffi.helpers.log("error", perr:format())
        return
    end

    local rerr = sciffi.helpers.handle_portal_result(result)
    if rerr then
        sciffi.helpers.log("error", rerr:format())
        return
    end
end

sciffi.interpretators.python = interpretator

return interpretator
