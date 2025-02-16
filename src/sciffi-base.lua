-- TODO: check for shell escape

-- FOR SOME REASON UNKNOWN TO ME THEY FORBID TO CALL `callback.register`
-- this trick ensures this function will be present
if luatexbase then
    local _luatexbase = luatexbase
    luatexbase.uninstall()
    -- @diagnostic disable-next-line: lowercase-global
    luatexbase = _luatexbase
end

--- @class Interpretator
--- @field execute fun(code: string): nil

--- @class (exact) SciFFI
--- @field public interpretators { [string]: Interpretator }
--- @field public helpers Helpers
--- @field public portals Portal[]
--- @field private env SciFFIEnv
sciffi = {
    interpretators = {},
}


-- TODO: test for subfiles
--- @class SciFFIEnv
--- @field lines string[]
--- @field private interpretator string
--- @field private previous_callback function | nil
--- @field private callback fun(line: string): string | nil
--- @field private start fun(interpretator: string): nil
--- @field private close fun(): nil
sciffi.env = {
    lines = {}
}

--- @param interpretator string
--- @return nil
function sciffi.env.start(interpretator)
    if not sciffi.interpretators[interpretator] then
        sciffi.helpers.log(
            "error",
            "sciffi environment cannot find interpretator \"" .. interpretator .. '"'
        )
        return
    end
    sciffi.env.interpretator = interpretator
    sciffi.env.previous_callback = callback.find("process_input_buffer")
    local _, err = callback.register("process_input_buffer", sciffi.env.callback)
    if err then
        sciffi.helpers.log(
            "error",
            "sciffi environment cannot register `process_input_buffer` callback"
        )
        sciffi.env.close()
        return
    end
end

--- @param line string
--- @return string | nil
function sciffi.env.callback(line)
    local pos = line:find("\\end{sciffi}")
    if not pos then
        table.insert(sciffi.env.lines, line)
        return ""
    end
    local before = line:sub(1, pos - 1)
    local after = line:sub(pos)

    table.insert(sciffi.env.lines, before)
    return after
end

--- @return nil
function sciffi.env.close()
    local _, err = callback.register("process_input_buffer", sciffi.env.previous_callback)
    if err then
        sciffi.helpers.log(
            "error",
            "sciffi environment cannot re-register previous `process_input_buffer` callback"
        )
        return
    end

    callback.previous_callback = nil
    sciffi.interpretators[sciffi.env.interpretator].execute(table.concat(sciffi.env.lines, "\n"))
    sciffi.env.lines = {}
end

--- @alias SciFFILogLevel
--- | "none"
--- | "debug"
--- | "info"
--- | "warning"
--- | "error"
--- | "critical"
--- | string

-- TODO: make a helper function which creates "base" portal skeleton

--- @class (exact) Helpers
--- @field deindent fun(code: string): string
--- @field save_snippet fun(code: string, extension: string?, path: string?): (string | nil, nil | string)
--- @field print fun(output: string): nil
--- @field errformat fun(opts: { portal: string | nil, interpretator: string | nil, msg: string }): string
--- @field handle_portal_result fun(result: PortalLaunchResult): string?
--- @field log fun(level: SciFFILogLevel, msg: string): nil
sciffi.helpers = {}

--- @param code string
--- @return string
function sciffi.helpers.deindent(code)
    code = code:match("^\n*(.-)\n*$")

    local min_indent = math.huge
    for line in code:gmatch("[^\n]+") do
        local leading_spaces = line:match("^(%s*)")
        if #line > 0 then
            min_indent = math.min(min_indent, #leading_spaces)
        end
    end

    local result = code:gsub("([^\n]+)", function(line)
        return line:sub(min_indent + 1)
    end)

    return result
end

--- @param code string
--- @param extension string?
--- @param path string?
--- @return string?
--- @return string?
function sciffi.helpers.save_snippet(code, extension, path)
    path = path or (os.tmpname() .. (extension or ""))
    local file = io.open(path, "w")
    if not file then
        return nil, "Error creating temporary file with code at " .. file
    end

    file:write(code)
    file:close()
    return path, nil
end

--- @param output string
--- @return nil
function sciffi.helpers.print(output)
    for line in output:gmatch("(.-)\n") do
        tex.print(line)
    end
end

--- @param level SciFFILogLevel
--- @param msg string
--- @return nil
function sciffi.helpers.log(level, msg)
    -- TODO: configuring?
    local target = "term and log"
    if level == "debug" then
        target = "log"
    end

    -- TODO: colors?
    texio.write_nl(target, "[" .. level .. "]" .. msg)
end

--- @param opts { portal: string | nil, interpretator: string | nil, msg: string }
--- @return string
function sciffi.helpers.errformat(opts)
    local errmsg = ""
    if opts.portal then
        errmsg = errmsg .. opts.portal
    end

    if opts.interpretator then
        errmsg = errmsg .. "<" .. opts.interpretator .. ">"
    end

    return errmsg .. ": " .. opts.msg
end

--- @param result PortalLaunchResult
--- @return string? error
--- @nodiscard
function sciffi.helpers.handle_portal_result(result)
    for _, v in ipairs(result) do
        if v.tag == "tex" then
            sciffi.helpers.print(v.value)
        elseif v.tag == "log" then
            sciffi.helpers.log(v.value.level, v.value.msg)
        end
    end
end

-- TODO: narrowing?

--- @alias PortalLaunchResult { [integer] : PortalLaunchResultField }
--- @alias PortalLaunchResultField
--- | { tag : "tex", value : string}
--- | { tag : "log", value : { level : string, msg: string }}

--- @class Portal
--- @field setup fun(opts: table): (Portal | nil, nil | string)
--- @field launch fun(): (PortalLaunchResult | nil, nil | string)
sciffi.portals = {}

--- @class SimplePortal : Portal
--- @field file string
--- @field code string | nil
--- @field interpretator string
--- @field command string
--- @field stderrfile string
sciffi.portals.simple = {}

--- @class SimplePortalOpts
--- @field file string
--- @field code string?
--- @field interpretator string
--- @field command string
--- @field stderrfile string?

--- @param opts SimplePortalOpts
--- @return SimplePortal portal
--- @return string? error
--- @nodiscard
function sciffi.portals.simple.setup(opts)
    local portal = {
        setup = sciffi.portals.simple.setup,
        launch = sciffi.portals.simple.launch,
        file = opts.file,
        stderrfile = opts.stderrfile or os.tmpname(),
        code = opts.code,
        command = opts.command,
        interpretator = opts.interpretator
    }
    return portal, nil
end

--- @param self SimplePortal
--- @return PortalLaunchResult
--- @return string? error
--- @nodiscard
function sciffi.portals.simple.launch(self)
    local code = self.code
    if code then
        local file = io.open(self.file, "w")
        if not file then
            return {}, sciffi.helpers.errformat({
                interpretator = self.interpretator,
                portal = "SimplePortal",
                msg = "Error creating temporary file with code at " .. file
            })
        end

        file:write(code)
        file:close()
    end

    local com = string.format("%s %s 2> %s", self.command, self.file, self.stderrfile)
    local file = io.popen(com, "r")
    if not file then
        return {}, sciffi.helpers.errformat({
            interpretator = self.interpretator,
            portal = "SimplePortal",
            msg = "Error executing command " .. self.command
        })
    end

    local output = file:read("*a")
    file:close()

    local stderroutput = "Couldn't open stderr file"
    file = io.open(self.stderrfile, "r")
    if file then
        stderroutput = file:read("*a")
        file:close()
    end

    local errmsg = sciffi.helpers.errformat({
        interpretator = self.interpretator,
        portal = "SimplePortal",
        msg = stderroutput
    })

    return {
        {
            tag = "tex", value = output
        },
        {
            tag = "log",
            value = {
                level = "warning", msg = errmsg
            }
        }
    }, nil
end

return sciffi
