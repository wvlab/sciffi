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
--- @field execute_snippet fun(code: string, options: string | table): nil
--- @field execute_script fun(filepath: string, options: string | table): nil

--- @class (exact) SciFFI
--- @field public interpretators table<string, Interpretator>
--- @field public portals table<string, Portal>
--- @field public helpers SciFFIHelpers
--- @field public err SciFFIErrMod
--- @field private env SciFFIEnv
--- @field private execute_snippet fun(interpretator: Interpretator, code: string, options: string): nil
--- @field private execute_script fun(interpretator: Interpretator, filepath: string, options: string): nil
sciffi = {}

-- TODO: test for subfiles
--- @class SciFFIEnvObject
--- @field envname string
--- @field lines string[]
--- @field options string
--- @field interpretator string
--- @field previous_callback function | nil

--- @class SciFFIEnv
--- @field private callback fun(env: SciFFIEnvObject): fun(line: string): string | nil
--- @field private start fun(envname: string, interpretator: string, options: string): nil
--- @field private close fun(env: SciFFIEnvObject): nil
--- @field private _state SciFFIEnvObject | nil
sciffi.env = {
    _state = nil
}

--- @param envname string
--- @param interpretator string
--- @param options string
--- @return SciFFIEnvObject | nil
function sciffi.env.start(envname, interpretator, options)
    --- @type SciFFIEnvObject
    local env = {
        envname = envname,
        options = options,
        lines = {},
        interpretator = interpretator,
        previous_callback = callback.find("process_input_buffer")
    }

    if not sciffi.interpretators[interpretator] then
        sciffi.helpers.log(
            "error",
            ('sciffi environment cannot find interpretator "%s"'):format(interpretator)
        )
        return
    end

    local _, err = callback.register("process_input_buffer", sciffi.env.callback(env))
    if err then
        sciffi.helpers.log(
            "error",
            "sciffi environment cannot register `process_input_buffer` callback"
        )
        sciffi.env.close(env)
        return nil
    end

    return env
end

--- @param env SciFFIEnvObject
--- @return fun(string): string | nil
function sciffi.env.callback(env)
    return function(line)
        local pos = line:find(string.format([[\end{%s}]], env.envname))
        if not pos then
            table.insert(env.lines, line)
            return ""
        end

        local before = line:sub(1, pos - 1)
        local after = line:sub(pos)

        table.insert(env.lines, before)
        return after
    end
end

--- @param env SciFFIEnvObject
--- @return nil
function sciffi.env.close(env)
    local _, err = callback.register("process_input_buffer", env.previous_callback)
    if err then
        sciffi.helpers.log(
            "error",
            "sciffi environment cannot re-register previous `process_input_buffer` callback"
        )
        return
    end

    callback.previous_callback = nil
    sciffi.interpretators[env.interpretator].execute_snippet(
        table.concat(env.lines, "\n"),
        env.options
    )
end

function sciffi.execute_script(interpretator, script_path, options)
    return sciffi.interpretators[interpretator].execute_script(script_path, options)
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

--- @class SciFFIEnumValue
--- @field value string

--- @alias SciFFIEnum { [string]: SciFFIEnumValue}

--- @param ... string
--- @return SciFFIEnum
local function defenum(...)
    local result = {}
    for _, name in ipairs({ ... }) do
        result[name] = { value = name }
    end

    return result
end

--- @class SciFFIErrMod
sciffi.err = {}

--- TODO: add motivation why
--- @class SciFFIError
--- @field tag SciFFIEnumValue
--- @field format fun(self: SciFFIError): string
--- @field data table | nil
--- @field src string
--- @field fname string
--- @field fnline integer
--- @field line integer

--- @generic Tag: SciFFIEnumValue
--- @generic Data: table | nil
--- @param tag Tag
--- @param format (fun(self: SciFFIError): string) | nil
--- @param data Data
--- @return SciFFIError
function sciffi.err.new(tag, format, data)
    local info = debug and debug.getinfo(2, "Sln") or {} -- 2 will get caller

    return {
        tag = tag,
        format = format or sciffi.err.format,
        data = data,
        src = info.short_src or "?",
        fname = info.name or "?",
        fnline = info.linedefined or -1,
        line = info.currentline or -1,
    }
end

--- @param err SciFFIError
--- @return string
function sciffi.err.format(err)
    return err.tag.value
end

local helpers_errenum = defenum("tmpfilefail")

--- @class SciFFIHelpers
sciffi.helpers = {
    err = helpers_errenum,
    defenum = defenum,
}

--- @param code string
--- @return string
function sciffi.helpers.deindent(code)
    code = code:match("^\n*(.-)\n*$")
    local min_indent = math.huge
    for line in code:gmatch("[^\n]+") do
        if not line:match("^%s*$") then
            local leading_spaces = line:match("^(%s*)")
            if #line > 0 then
                min_indent = math.min(min_indent, #leading_spaces)
            end
        end
    end

    local result = code:gsub("([^\n]+)", function(line)
        if line:match("^%s*$") then
            return ""
        end

        return line:sub(min_indent + 1)
    end)

    return result
end

--- @param options string | table
--- @return table
function sciffi.helpers.parse_options(options)
    if type(options) == "table" then
        return options
    end

    if type(options) ~= "string" then
        return {}
    end

    local result = {}
    options = options:gsub("%s*=%s*", "="):gsub("%s*,%s*", ",")
    for key, value in options:gmatch("([^,=]+)=([^,=]+)") do
        key = key:match("^%s*(.-)%s*$") or key
        value = value:match("^%s*(.-)%s*$") or value
        if key ~= "" and value ~= "" then
            result[key] = value
        end
    end

    return result
end

--- @param code string
--- @param extension? string
--- @param path? string
--- @return string
--- @return SciFFIError?
function sciffi.helpers.save_snippet(code, extension, path)
    path = path or (os.tmpname() .. (extension or ""))
    local file = io.open(path, "w")
    if not file then
        return "", sciffi.err.new(
            sciffi.helpers.err.tmpfilefail,
            sciffi.helpers.fmterr,
            { path = path }
        )
    end

    file:write(code)
    file:close()
    return path, nil
end

--- @param output string
--- @return nil
function sciffi.helpers.print(output)
    if not output:find("\n") then
        tex.print(output)
        return
    end

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
--- @return SciFFIError? error
--- @nodiscard
function sciffi.helpers.handle_portal_result(result)
    for _, v in ipairs(result) do
        if v.tag == "tex" then
            sciffi.helpers.print(v.value)
        elseif v.tag == "log" then
            sciffi.helpers.log(v.value.level, v.value.msg)
        end
    end

    return nil
end

--- @param err SciFFIError
--- @return string
function sciffi.helpers.fmterr(err)
    if err.tag == sciffi.helpers.err.tmpfilefail then
        return ("Error creating temporary file with code at %s"):format(err.data.path)
    end

    return sciffi.err.format(err)
end

-- TODO: narrowing?

--- @alias PortalLaunchResult [PortalLaunchResultField]
--- @alias PortalLaunchResultField
--- | { tag : "tex", value : string}
--- | { tag : "log", value : { level : string, msg: string }}

--- @generic PortalOpts
--- @class Portal<PortalOpts>
--- @field setup fun(opts: `PortalOpts`): (Portal<`PortalOpts`>, SciFFIError?)
--- @field launch fun(): (PortalLaunchResult, SciFFIError?)

--- @type table<string, Portal>
sciffi.portals = {}

--- @class SimplePortalOpts
--- @field interpretator string
--- @field command string
--- @field filepath string
--- @field stderrfile string?

local portals_simple_errenum = defenum("execfail", "failstderr")

--- @class SimplePortal : SimplePortalOpts, Portal<SimplePortalOpts>,
sciffi.portals.simple = {
    err = portals_simple_errenum,
}

--- @param opts SimplePortalOpts
--- @return SimplePortal portal
--- @return SciFFIError? error
--- @nodiscard
function sciffi.portals.simple.setup(opts)
    local portal = {
        setup = sciffi.portals.simple.setup,
        launch = sciffi.portals.simple.launch,
        err = sciffi.portals.simple.err,
        fmterr = sciffi.portals.simple.fmterr,
        interpretator = opts.interpretator,
        command = opts.command,
        filepath = opts.filepath,
        stderrfile = opts.stderrfile or os.tmpname(),
    }
    return portal, nil
end

--- @param self SimplePortal
--- @return PortalLaunchResult
--- @return SciFFIError? error
--- @nodiscard
function sciffi.portals.simple.launch(self)
    local com = string.format("%s %s 2> %s", self.command, self.filepath, self.stderrfile)
    local file = io.popen(com, "r")
    if not file then
        return {}, sciffi.err.new(
            sciffi.portals.simple.err.execfail,
            sciffi.portals.simple.fmterr,
            {
                command = self.command,
                interpretator = self.interpretator,
            }
        )
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

    local result = {
        {
            tag = "tex", value = output
        },
    }

    if stderroutput ~= "" then
        table.insert(result, {
            tag = "log",
            value = {
                level = "warning", msg = errmsg
            },
        })
    end

    return result, nil
end

--- @param err SciFFIError
--- @return string
function sciffi.portals.simple.fmterr(err)
    if err.tag == sciffi.portals.simple.err.execfail then
        return ("Error executing command: %s"):format(err.data.command)
    end

    return sciffi.err.format(err)
end

--- @type table<string, Interpretator>
sciffi.interpretators = {}

--- @class GenericInterpretator
sciffi.interpretators.generic = {}

function sciffi.interpretators.generic.execute_snippet(code, options)
    options = sciffi.helpers.parse_options(options)

    local filepath, err = sciffi.helpers.save_snippet(
        sciffi.helpers.deindent(code), options.extension
    )

    if err then
        sciffi.helpers.log("error", err:format())
        return
    end

    sciffi.interpretators.generic.execute_script(filepath, options)
end

function sciffi.interpretators.generic.execute_script(filepath, options)
    options = sciffi.helpers.parse_options(options)

    if not options.command then
        sciffi.helpers.log("error", sciffi.helpers.errformat({
            interpretator = options.name or "generic",
            msg = "Command must not be empty"
        }))
    end

    local portal, err = sciffi.portals.simple.setup({
        interpretator = options.name or "generic",
        filepath = filepath,
        command = options.command,
    })

    if err ~= nil then
        sciffi.helpers.log("error", err:format())
        return
    end

    local result, lerr = portal:launch()
    if lerr ~= nil then
        sciffi.helpers.log("error", lerr:format())
        return
    end

    if options.silence == "true" then
        local res = {}
        for i, v in pairs(result) do
            if v.tag ~= "tex" then
                res[i] = v
            end
        end

        result = res
    end

    local hperr = sciffi.helpers.handle_portal_result(result)
    if hperr ~= nil then
        sciffi.helpers.log("error", hperr:format())
        return
    end
end

return sciffi
