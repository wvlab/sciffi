require("sciffi-base")

sciffi.interpretators.python = {
    execute = function(code)
        local filepath, err = sciffi.helpers.save_snippet(sciffi.helpers.deindent(code), ".py")
        if err then
           --- @cast filepath string
           sciffi.helpers.log("error", err)
           return
        end

        local portal, err = sciffi.portals.simple.setup(
            {
                interpretator = "python",
                filepath = filepath,
                code = sciffi.helpers.deindent(code),
                command = "python"
            }
        )

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
