require("sciffi-base")
local socket = require("socket")
local ffi = require("ffi")
local proto = require("sciffi-cosmo-proto")

--- @class Pid
--- @class SpawnFileActions
--- @class SpawnAttributes

ffi.cdef([[
    typedef int32_t pid_t; // i am not entirely sure about this

    pid_t waitpid(pid_t pid, int *stat_loc, int options);

    typedef struct {} posix_spawn_file_actions_t;
    typedef struct {} posix_spawnattr_t;

    // see man posix_spawn(3)
    int posix_spawnp(
        pid_t *pid, const char *path,
        const posix_spawn_file_actions_t *file_actions,
        const posix_spawnattr_t *attrp,
        char *const argv[], char *const envp[]
    );

    int posix_spawn_file_actions_init(posix_spawn_file_actions_t *file_actions);
    int posix_spawn_file_actions_destroy(posix_spawn_file_actions_t *file_actions);

    int posix_spawnattr_init(posix_spawnattr_t *attr);
    int posix_spawnattr_destroy(posix_spawnattr_t *attr);
]])

--- Parses all current environment variables and places into a table
--- If an error occurs returns empty table and description of an error
---
--- Dependent on the os:
---   * Reads /proc/self/environ on linux
---   * Reads os.env
--- @private
--- @return string[] environ
--- @return string? error
local function environ()
    local env = {}

    if ffi.os == "Linux" then
        local f = io.open("/proc/self/environ")
        if not f then
            error()
        end

        for str in f:read("a"):gmatch("([^\0]+)") do
            table.insert(env, str)
        end

        f:close()
    else
        for k, v in ipairs(os.env) do env[k] = v end
    end

    return env, nil
end

--- @private
--- @return Pid
local function new_pid()
    return ffi.cast("pid_t *", ffi.new("pid_t[1]"))
end

--- @private
--- @param pid Pid
--- @return boolean
local function is_alive(pid)
    local rc = ffi.C.waitpid(pid[0], nil, 1)
    if rc == 0 then
        return true
    end

    return false
end

--- @private
--- @return SpawnFileActions
--- @return integer? errorcode
--- @return string? error
local function new_file_actions()
    --- @type SpawnFileActions
    local actions = ffi.new("posix_spawn_file_actions_t")

    --- @type integer
    local status = ffi.C.posix_spawn_file_actions_init(actions)

    if status ~= 0 then
        return actions, status, ("posix_spawn_file_actions_init failed with status: %d"):format(status)
    end

    return actions, status, nil
end

--- @private
--- @param actions SpawnFileActions
local function del_file_actions(actions)
    ffi.C.posix_spawn_file_actions_destroy(actions)
end

--- @private
--- @return SpawnAttributes
--- @return integer? errorcode
--- @return string? error
local function new_spawn_attrs()
    --- @type SpawnAttributes
    local attrs = ffi.new("posix_spawnattr_t")

    --- @type integer
    local status = ffi.C.posix_spawnattr_init(attrs)

    if status ~= 0 then
        return attrs, status, ("posix_spawnattr_init failed with status: %d"):format(status)
    end

    return attrs, status, nil
end

--- @private
--- @param attrs SpawnAttributes
local function del_spawn_attrs(attrs)
    ffi.C.posix_spawnattr_destroy(attrs)
end

--- @param command string
--- @param args string[]
local function argv(command, args)
    local res = ffi.new("char *[?]", #args + 2)
    res[0] = ffi.cast("char *", command)
    for i, v in pairs(args) do
        res[i] = ffi.cast("char *", v)
    end
    res[#args + 1] = nil
    res = ffi.cast("char *const *", res)
    return res
end

--- Spawns a subprocess using posix_spawn,
--- uses default file actions and spawn attributes
--- @private
--- @param command string
--- @param args string[]
--- @param env string[]
--- @return Pid
--- @return string? err
local function spawn(command, args, env)
    local pid = new_pid()

    local actions, _, faerr = new_file_actions()
    if faerr then
        return pid, faerr
    end

    local attrs = nil -- , _, saerr = new_spawn_attrs()
    -- if saerr then
    --     del_file_actions(actions)
    --     return pid, saerr
    -- end

    local status = ffi.C.posix_spawnp(
        pid,
        command,
        actions,
        attrs,
        argv(command, args),
        env
    )

    if status ~= 0 then
        return pid, ("posix_spawn failed with status: %d"):format(status)
    end

    return pid, nil
end

-- TODO: add option for startup timeout
--- @class CosmoPortalOpts
--- @field interpretator string
--- @field command string
--- @field filepath string
--- @field address string?
--- @field port integer?
--- @field timeout integer?


local errenum = sciffi.helpers.defenum(
    "sockbindfail",
    "procdead",
    "invalidmsgtag",
    "invalidmsgid",
    "invalidpayloadlen",
    "luasocketfail"
)

--- @class CosmoPortal : CosmoPortalOpts, Portal
--- @field server TCPSocketServer
sciffi.portals.cosmo = {
    err = errenum,
}

--- @param opts CosmoPortalOpts
--- @return CosmoPortal self
--- @return string? err
function sciffi.portals.cosmo.setup(opts)
    local address = opts.address or "127.0.0.1"

    local server = socket.bind(address, opts.port or 0)
    if not server then
        return {},
            sciffi.err.new(
                errenum.sockbindfail,
                sciffi.portals.cosmo.fmterr,
                { address = address, port = opts.port }
            )
            :format()
    end

    local _, port, _ = server:getsockname()

    sciffi.helpers.log(
        "info",
        ("Binded tcp socket to %s with port %d\n"):format(address, port)
    )

    return {
        setup = sciffi.portals.cosmo.setup,
        launch = sciffi.portals.cosmo.launch,
        err = sciffi.portals.cosmo.err,
        fmterr = sciffi.portals.cosmo.fmterr,
        interpretator = opts.interpretator,
        command = opts.command,
        filepath = opts.filepath,
        address = opts.address,
        port = port,
        server = server,
        timeout = opts.timeout or 1,
    }, nil
end

--- @param pid Pid
--- @param sock TCPSocketClient
--- @return CosmoProtoMessage
--- @return SciFFIError? error
local function req(pid, sock)
    local data, err = sock:receive(proto.HEADERLEN)
    if err == "timeout" then
        if not is_alive(pid) then
            return {}, sciffi.err.new(errenum.procdead, sciffi.portals.cosmo.fmterr, nil)
        end
    end

    if err or data == nil then
        return {}, sciffi.err.new(
            errenum.luasocketfail,
            sciffi.portals.cosmo.fmterr,
            { reason = err or "no data" }
        )
    end

    local header = proto.header(data)
    local payloadbytes, perr = sock:receive(header.payloadlen)
    if perr or payloadbytes == nil then
        return {}, sciffi.err.new(
            errenum.luasocketfail,
            sciffi.portals.cosmo.fmterr,
            { reason = err or "no data" }
        )
    end

    local payload, _ = proto.payload(header, payloadbytes or "")

    return proto.message(header, payload), nil
end

--- @param pid Pid
--- @param sock TCPSocketClient
--- @param timeout? number
--- @return integer version
--- @return SciFFIError? error
local function handshake(pid, sock, timeout)
    sock:settimeout(timeout or 1)
    local msg, err = req(pid, sock)
    if err ~= nil then
        return 0, err
    end

    if msg.header.messagetag ~= proto.MSGTYPE.handshake then
        return 0, sciffi.err.new(
            errenum.invalidmsgtag,
            sciffi.portals.cosmo.fmterr,
            { expected = 0x01, actual = msg.header.messagetag }
        )
    end

    if msg.header.messageid ~= 0 then
        return 0, sciffi.err.new(
            errenum.invalidmsgtag,
            sciffi.portals.cosmo.fmterr,
            { expected = 0x01, actual = msg.header.messageid }
        )
    end

    if msg.header.payloadlen ~= 2 then
        return 0, sciffi.err.new(
            errenum.invalidpayloadlen,
            sciffi.portals.cosmo.fmterr,
            { expected = 2, actual = msg.header.payloadlen }
        )
    end

    return msg.payload.version, nil
end

--- @param pid Pid
--- @param sock TCPSocketClient
--- @return PortalLaunchResult
--- @return SciFFIError? error
local function serve(pid, sock, version)
    _ = version -- for now we will ignore it

    --- @type PortalLaunchResult
    local result = {}

    while true do
        local msg, err = req(pid, sock)
        if err ~= nil then
            return result, err
        end

        -- if msg.header.messagetag == proto.MSGTYPE.getregister then
        --     -- TODO: implement
        -- end

        -- if msg.header.messagetag == proto.MSGTYPE.putregister then
        --     -- TOOD: implement
        -- end

        if msg.header.messagetag == proto.MSGTYPE.write and msg.payload.tag == "write" then
            table.insert(result, { tag = "tex", value = msg.payload.data })
        end

        if msg.header.messagetag == proto.MSGTYPE.log and msg.payload.tag == "log" then
            table.insert(result, {
                tag = "log",
                value = {
                    level = msg.payload.level,
                    msg = msg.payload.message,
                },
            })
        end

        if msg.header.messagetag == proto.MSGTYPE.close then
            break
        end
    end

    return result, nil
end

--- @param self CosmoPortal
--- @return PortalLaunchResult
--- @return string? error
--- @nodiscard
function sciffi.portals.cosmo:launch()
    local env = environ()
    local cenv = ffi.new("char *[?]", #env + 2)
    cenv[0] = ffi.cast("char *", "SCIFFI_PORT=" .. tostring(self.port))
    for i, v in pairs(env) do
        cenv[i] = ffi.cast("char *", v)
    end
    cenv[#env + 1] = nil

    cenv = ffi.cast("char *const *", cenv)

    local pid = spawn(self.command, { self.filepath }, cenv)

    self.server:settimeout(self.timeout)

    local sock, err
    while true do
        sock, err = self.server:accept()
        if err == "timeout" then
            if not is_alive(pid) then
                return {}, sciffi.err.new(errenum.procdead, sciffi.portals.cosmo.fmterr, nil):format()
            end
        elseif sock ~= nil then
            break
        else
            return {}, err
        end
    end

    if err or not sock then
        self.server:close()
        return {}, sciffi.helpers.errformat({
            interpretator = self.interpretator,
            portal = "CosmoPortal",
            msg = "Error executing command " .. self.command
        })
    end

    local version, herr = handshake(pid, sock)
    _ = herr

    local res, serr = serve(pid, sock, version)
    return res, serr and serr:format() or nil
end

--- @param err SciFFIError
--- @return string
function sciffi.portals.cosmo.fmterr(err)
    if err.tag == errenum.sockbindfail then
        return ("Error binding tcp socket to %s with port %d"):format(err.data.address, err.data.port)
    end

    if err.tag == errenum.procdead then
        return "Process died before sending close"
    end

    if err.tag == errenum.invalidmsgtag then
        return ("Invalid message tag, expected %x, got %x"):format(err.data.expected, err.data.actual)
    end

    if err.tag == errenum.invalidmsgid then
        return ("Invalid message id, expected %d, got %d"):format(err.data.expected, err.data.actual)
    end

    if err.tag == errenum.invalidpayloadlen then
        return ("Invalid payload length, expected %d, got %d"):format(err.data.expected, err.data.actual)
    end

    if err.tag == errenum.luasocketfail then
        return ("Lua socket receive bytes failed with following reason: %s"):format(err.data.reason)
    end

    return sciffi.err.format(err)
end

return sciffi.portals.cosmo
