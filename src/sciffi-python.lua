require("sciffi-base")

sciffi.interpretators.python = {
    execute = function(code)
        local portal, err = sciffi.portals.simple.setup(
            {
                interpretator = "python",
                file = os.tmpname() .. ".py",
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
