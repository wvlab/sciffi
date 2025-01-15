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
            -- TODO: refactor when warning error api
            print(err)
            return
        end

        local result, err = portal:launch()
        if err then
            -- TODO: refactor when warning error api
            print(err)
            return
        end

        local err = sciffi.helpers.handle_portal_result(result)
        if err then
            -- TODO: refactor when warning error api
            print(err)
            return
        end
    end
}
