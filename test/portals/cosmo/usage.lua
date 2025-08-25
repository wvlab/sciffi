local _ = require("sciffi-base")
local cosmo = require("sciffi-cosmo")
local t = require("test.t")

return {
    {
        name = "portal timeouts signaling process is dead",
        tags = t.tags(
            "portals", "portals-cosmo", "portals-cosmo", "portals-cosmo-usage"
        ),
        test = function()
            local portal, serr = cosmo.setup({
                interpretator = "test",
                command = 'texlua -e "os.exit()"',
                filepath = "",
                timeout = 1,
            })

            t.assertnil(serr)
            local res, err = portal:launch()
            t.assertdeepeql(res, {})
            t.asserteql(err, "process is dead")
        end
    },
}
