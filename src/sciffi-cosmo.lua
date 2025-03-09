require("sciffi-base")
local socket = require("socket")
local ffi = require("ffi")

ffi.cdef([[
    typedef int32_t pid_t; // i am not entirely sure about this

    typedef struct {} posix_spawn_file_actions_t;
    typedef struct {} posix_spawnattr_t;

    int posix_spawnp(pid_t *pid, const char *path,
                    const posix_spawn_file_actions_t *file_actions,
                    const posix_spawnattr_t *attrp,
                    char *const argv[], char *const envp[]);

    int posix_spawn_file_actions_init(posix_spawn_file_actions_t *file_actions);
    int posix_spawn_file_actions_destroy(posix_spawn_file_actions_t *file_actions);

    int posix_spawnattr_init(posix_spawnattr_t *attr);
    int posix_spawnattr_destroy(posix_spawnattr_t *attr);

    int kill(pid_t pid, int sig);
]])

local function environ()
    -- TODO: add error handling
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
        error()
    end

    return env
end

local function spawn(command, args, env)
    local status
    local pid = ffi.new("pid_t[1]")

    local file_actions = ffi.new("posix_spawn_file_actions_t")
    status = ffi.C.posix_spawn_file_actions_init(file_actions)
    if status ~= 0 then
        error("posix_spawn_file_actions_init failed with status: " .. status)
    end

    -- Initialize attributes (empty)
    local attr = ffi.new("posix_spawnattr_t")
    status = ffi.C.posix_spawnattr_init(attr)
    if status ~= 0 then
        ffi.C.posix_spawn_file_actions_destroy(file_actions)
        error("posix_spawnattr_init failed with status: " .. status)
    end

    local argv = ffi.new("char *[?]", #args + 2)
    argv[0] = ffi.cast("char *", command)
    for i, v in pairs(args) do
        argv[i] = ffi.cast("char *", v)
    end
    argv[#args + 1] = nil
    argv = ffi.cast("char *const *", argv)

    status = ffi.C.posix_spawnp(pid, command, file_actions, attr, argv, env)
    if status ~= 0 then
        -- TODO: it's better to return error
        error("posix_spawn failed with status: " .. status)
    end

    return pid[0]
end

--- @class CosmoPortal : Portal
--- @field server TCPSocketServer
--- @field filepath string
--- @field interpretator string
--- @field command string
--- @field port integer
sciffi.portals.cosmo = {}

--- @class CosmoPortalOpts
--- @field address string?
--- @field port integer?
--- @field filepath string
--- @field interpretator string
--- @field command string

--- @param opts CosmoPortalOpts
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

    local portal = {
        setup = sciffi.portals.cosmo.setup,
        launch = sciffi.portals.cosmo.launch,
        filepath = opts.filepath,
        port = port,
        server = server,
        interpretator = opts.interpretator,
        command = opts.command
    }
    return portal, nil
end

--- @param self CosmoPortal
--- @return PortalLaunchResult
--- @return string? error
--- @nodiscard
function sciffi.portals.cosmo.launch(self)
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
