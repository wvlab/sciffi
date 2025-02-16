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
        local portal, err = sciffi.portals.simple.setup({
            interpretator = "python",
            filepath = filepath,
            command = "python"
        })

        if err then
            sciffi.helpers.log("error", err)
            return
        end

        local result, err = portal:launch()
        if err then
            sciffi.helpers.log("error", err)
            return
        end

        local err = sciffi.helpers.handle_portal_result(result)
        if err then
            sciffi.helpers.log("error", err)
            return
        end
    end
}
