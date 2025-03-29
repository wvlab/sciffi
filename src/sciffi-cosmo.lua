-- [[
-- All messages follow this structure:
-- [1 byte ] Message tag
-- [2 bytes] Message id (should be unique)
-- [4 bytes] Payload buffer length
-- [n bytes] Payload itself
--
-- HANDSHAKE
-- 0x00 0x00 (should be the first message)
-- 0x00 0x00 0x00 0x02
-- [2 bytes] version
--
-- just a generic response from server
-- RESPONSE
-- message_id (should mirror message_id from request)
-- amount of bytes > 1
-- [1 byte ] response code
-- [n bytes] data
--
-- GETREGISTER
-- message_id
-- amount of bytes > 1
-- [1 byte ] register type
-- [n bytes] register name
-- 0x00
-- [k bytes] string
--
-- PUTREGISTER
-- message_id
-- amount of bytes
-- [1 byte ] register type
-- [n bytes] register name
-- 0x00
-- [k bytes] data
--
-- WRITE
-- message_id
-- amount of bytes
-- payload which should be valid tex
--
-- LOG
-- message_id
-- amount of bytes
-- log level
-- 0x00
-- log msg
--
-- CLOSE
-- message_id (should be the last message)
-- 0x00 0x00 0x00 0x00 (no payload)
--
-- ]]
--
-- TODO: add network order

require("sciffi-base")
local socket = require("socket")
local ffi = require("ffi")

local MSG_TYPE = {
    HANDSHAKE = 0x01,
    RESPONSE = 0x02,
    GETREGISTER = 0x03,
    PUTREGISTER = 0x04,
    WRITE = 0x05,
    LOG = 0x06,
    CLOSE = 0x07,
}

-- TODO: add glue registers
local REGISTER_TYPE = {
    COUNT = 0x01,
    DIMENSION = 0x02,
    TOKEN = 0x03,
    SKIP = 0x04,
    ATTRIBUTE = 0x05,
}

--- @class CosmoMessage
--- @field message_type integer
--- @field message_id integer
--- @field payload_length integer
--- @field payload string

--- @param bytes string
--- @return integer
local function bytes_to_int(bytes)
    local len = #bytes
    local result = 0
    for i = 1, len do
        local byte = string.byte(bytes, i)
        result = result + byte * 256 ^ (len - i)
    end
    return result
end

--- @param header string
--- @return integer tag
--- @return integer message_id
--- @return integer payload_length
local function parse_header(header)
    return
        bytes_to_int(string.sub(header, 1, 1)),
        bytes_to_int(string.sub(header, 2, 3)),
        bytes_to_int(string.sub(header, 4, 7))
end

--- @class Pid
--- @class SpawnFileActions
--- @class SpawnAttributes

ffi.cdef([[
    typedef int32_t pid_t; // i am not entirely sure about this

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
        return {}, ("can't read environment on OS: %s"):format(ffi.os)
    end

    return env, nil
end

--- @private
--- @return Pid
local function new_pid()
    return ffi.cast(
        "pid_t *",
        ffi.new("pid_t[1]")
    )
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

    local attrs, _, saerr = new_spawn_attrs()
    if saerr then
        del_file_actions(actions)
        return pid, saerr
    end

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

--- @class CosmoPortal : CosmoPortalOpts, Portal
--- @field server TCPSocketServer
sciffi.portals.cosmo = {}

--- @param opts CosmoPortalOpts
--- @return CosmoPortal self
--- @return string? err
function sciffi.portals.cosmo.setup(opts)
    local address = opts.address or "127.0.0.1"

    local server = socket.bind(address, opts.port or 0)
    if not server then
        return {}, sciffi.helpers.errformat({
            interpretator = opts.interpretator,
            portal = "CosmoPortal",
            msg = "Error binding tcp socket to " .. address .. "with port " .. (opts.port or "0 (any)")
        })
    end

    local port
    _, port = server:getsockname()

    sciffi.helpers.log(
        "info",
        "Binded tcp socket to " .. address .. "with port " .. port .. "\n"
    )

    return {
        setup = sciffi.portals.cosmo.setup,
        launch = sciffi.portals.cosmo.launch,
        interpretator = opts.interpretator,
        command = opts.command,
        filepath = opts.filepath,
        address = opts.address,
        port = port,
        server = server,
    }, nil
end

--- @param sock TCPSocketClient
--- @return CosmoMessage
--- @return string? error
local function handle_req(sock)
    local data, err = sock:receive(7)
    if err or not data then
        return {}, err or "no data"
    end

    local tag, msg_id, payload_len = parse_header(data)
    local payload, perr = sock:receive(payload_len)
    -- TODO: handle perr

    return {
        message_type = tag,
        message_id = msg_id,
        payload_length = payload_len,
        payload = payload
    }, nil
end

--- @param sock TCPSocketClient
--- @param timeout? number
--- @return integer version
--- @return string? error
local function handshake(sock, timeout)
    sock:settimeout(timeout or 1)
    local req, err = handle_req(sock)
    if err then
        return 0, err
    end
    if req.message_type ~= MSG_TYPE.HANDSHAKE then
        return 0, "some error"
    end

    if req.message_id ~= 0 then
        return 0, "some error 2"
    end

    if req.payload_length ~= 2 then
        return 0, "some error 3"
    end

    return bytes_to_int(req.payload)
end

--- @param sock TCPSocketClient
--- @return PortalLaunchResult
--- @return string? error
local function serve(sock, version)
    _ = version -- for now we will ignore it

    --- @type PortalLaunchResult
    local result = {}

    while true do
        local req = handle_req(sock)
        if req.message_type == MSG_TYPE.GETREGISTER then
            -- TODO: implement
        end

        if req.message_type == MSG_TYPE.PUTREGISTER then
            -- TOOD: implement
        end

        if req.message_type == MSG_TYPE.WRITE then
            table.insert(result, { tag = "tex", value = req.payload })
        end

        if req.message_type == MSG_TYPE.LOG then
            -- TODO: implement
        end

        if req.message_type == MSG_TYPE.CLOSE then
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

    local sock, err = self.server:accept()
    if err or not sock then
        self.server:close()
        return {}, sciffi.helpers.errformat({
            interpretator = self.interpretator,
            portal = "CosmoPortal",
            msg = "Error executing command " .. self.command
        })
    end

    local version, herr = handshake(sock)

    sock:settimeout(1)

    local r = serve(sock, version)
    return r
end
