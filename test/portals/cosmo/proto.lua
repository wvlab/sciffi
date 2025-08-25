local _ = require("sciffi-base")
local proto = require("sciffi-cosmo-proto")
local t = require("test.t")

return {
    {
        name = "header parses valid header correctly",
        tags = t.tags(
            "portals", "portals-cosmo", "portals-cosmo-proto",
            "portals-cosmo-proto-header"
        ),
        test = function()
            local bytes = string.pack(">I1I2I4", proto.MSGTYPE.handshake, 42, 10)
            local header, err = proto.header(bytes)

            t.assertnil(err)
            t.assertdeepeql(header, {
                messagetag = proto.MSGTYPE.handshake,
                messageid  = 42,
                payloadlen = 10
            })
        end
    },
    {
        name = "header fails on wrong length",
        tags = t.tags(
            "portals", "portals-cosmo", "portals-cosmo-proto",
            "portals-cosmo-proto-header"
        ),
        test = function()
            local bad_bytes = string.pack(">I1I2", proto.MSGTYPE.handshake, 1)
            local _, err = proto.header(bad_bytes)

            t.asserteql(err, "wrong header length")
        end
    },
    {
        name = "payload handshake parses version",
        tags = t.tags(
            "portals", "portals-cosmo", "portals-cosmo-proto",
            "portals-cosmo-proto-payload"
        ),
        test = function()
            local bytes = string.pack(">I2", 512)
            local header = { messagetag = proto.MSGTYPE.handshake, payloadlen = 2 }
            local p, err = proto.payload(header, bytes)

            t.assertnil(err)
            t.assertdeepeql(p, { tag = "handshake", version = 512 })
        end
    },
    {
        name = "payload getregister parses type, name, and string",
        tags = t.tags(
            "portals", "portals-cosmo", "portals-cosmo-proto",
            "portals-cosmo-proto-payload"
        ),
        test = function()
            local bytes = string.pack(">I1", 3) .. "regname\0value"
            local header = { messagetag = proto.MSGTYPE.getregister, payloadlen = bytes:len() }
            local p, err = proto.payload(header, bytes)

            t.assertnil(err)
            t.assertdeepeql(p, {
                tag    = "getregister",
                type   = 3,
                name   = "regname",
                string = "value"
            })
        end
    },
    {
        name = "payload putregister parses type, name, and data",
        tags = t.tags(
            "portals", "portals-cosmo", "portals-cosmo-proto",
            "portals-cosmo-proto-payload"
        ),
        test = function()
            local bytes = string.pack(">I1", 5) .. "regname\0DATA"
            local header = { messagetag = proto.MSGTYPE.putregister, payloadlen = bytes:len() }
            local p, err = proto.payload(header, bytes)

            t.assertnil(err)
            t.assertdeepeql(p, {
                tag  = "putregister",
                type = 5,
                name = "regname",
                data = "DATA"
            })
        end
    },
    {
        name = "payload log parses level and message",
        tags = t.tags(
            "portals", "portals-cosmo", "portals-cosmo-proto",
            "portals-cosmo-proto-payload"
        ),
        test = function()
            local bytes = string.pack(">I1", 2) .. "\0hello"
            local header = { messagetag = proto.MSGTYPE.log, payloadlen = bytes:len() }
            local p, err = proto.payload(header, bytes)

            t.assertnil(err)
            t.assertdeepeql(p, { tag = "log", level = 2, message = "hello" })
        end
    },
    {
        name = "payload write returns raw payload",
        tags = t.tags(
            "portals", "portals-cosmo", "portals-cosmo-proto",
            "portals-cosmo-proto-payload"
        ),
        test = function()
            local data = "rawtex"
            local header = { messagetag = proto.MSGTYPE.write, payloadlen = data:len() }
            local p, err = proto.payload(header, data)

            t.assertnil(err)
            t.assertdeepeql(p, { tag = "write", data = "rawtex" })
        end
    },
    {
        name = "payload close returns close tag",
        tags = t.tags(
            "portals", "portals-cosmo", "portals-cosmo-proto",
            "portals-cosmo-proto-payload"
        ),
        test = function()
            local header = { messagetag = proto.MSGTYPE.close, payloadlen = 0 }
            local p, err = proto.payload(header, "")

            t.assertnil(err)
            t.assertdeepeql(p, { tag = "close" })
        end
    },
    {
        name = "payload fails on wrong length",
        tags = t.tags(
            "portals", "portals-cosmo", "portals-cosmo-proto",
            "portals-cosmo-proto-payload"
        ),
        test = function()
            local header = { messagetag = proto.MSGTYPE.handshake, payloadlen = 5 }
            local _, err = proto.payload(header, "abc")

            t.asserteql(err, "wrong payload length")
        end
    }
}
