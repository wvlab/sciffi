require("sciffi-base")

sciffi.interpretators.python = {
    execute_snippet = function(code, options)
        local filepath, err = sciffi.helpers.save_snippet(sciffi.helpers.deindent(code), ".py")
        if err then
            --- @cast filepath string
            sciffi.helpers.log("error", err)
            return
        end
        sciffi.interpretators.python.execute_script(filepath, options)
    end,
    execute_script = function(filepath, options)
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

        if err then
            sciffi.helpers.log("error", err or "")
            return
        end

        local result, perr = portal:launch()
        if err then
            sciffi.helpers.log("error", perr or "")
            return
        end

        local rerr = sciffi.helpers.handle_portal_result(result)
        if err then
            sciffi.helpers.log("error", rerr or "")
            return
        end
    end
}

return sciffi.interpretators.python
