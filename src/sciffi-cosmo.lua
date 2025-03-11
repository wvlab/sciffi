require("sciffi-base")
local socket = require("socket")
local ffi = require("ffi")

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

    sock:settimeout(1)

    while true do
        local line, serr = sock:receive()
        sciffi.helpers.log("info", "CosmoPortal got the line: " .. (line or ""))

        if line == "" then
            break
        end
    end
end
