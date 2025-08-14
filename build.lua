local fennel = require("tools.fennel")

module = "sciffi"
tdsroot = "luatex"

local function endswith(str, suffix)
    return string.sub(str, -suffix:len()) == suffix
end

local function unfuckcomments(line)
    local comment, filename, linenum = line:match('do local _ = {";;(.-)", filename = "(.-)", line = (%d+)} end')
    local _ = { filename, linenum }

    if comment then
        return string.format("--%s", comment)
    end

    return line
end

local function compilefennel()
    local srcdir = "src/"
    local fennelopts = { comments = true, useBitLib = true }

    for filepath in lfs.dir(srcdir) do
        if endswith(filepath, ".fnl") then
            filepath = srcdir .. filepath
            local fnlfile = assert(io.open(filepath, "r"))
            local fnlsrc = fnlfile:read("a")
            local luasrc = fennel.compileString(fnlsrc, fennelopts)

            local lines = {}
            for line in luasrc:gmatch("[^\n]*") do
                table.insert(lines, unfuckcomments(line))
            end

            local luafile = assert(io.open(filepath:gsub(".fnl", ".lua"), "w"))
            luafile:write(table.concat(lines, "\n"))
            luafile:close()
        end
    end
end

installfiles = {
    "sciffi.sty",
    "sciffi-python.sty",
    "sciffi-fennel.sty",
    "sciffi-cosmo.lua",
    "sciffi-cosmo-proto.lua",
    "sciffi-python-matplotlib.sty",
    "sciffi-base.lua",
    "sciffi-python.lua",
    "sciffi-fennel.lua",
    "sciffi-python-matplotlib.lua",
}

docfiles = {
    "doc/*"
}

sourcefiles = {
    "src/*",
}

typesetfiles = {
    "doc/*.tex"
}

uploadconfig = {
    author = "wvlab",
    summary = "",
    pkg = module,
    version = "alpha",
    uploader = "wvlab",
    email = "me@wvlab.xyz",
    note = "",
    announcement_file = "",
    description = "",
    development = true,
    topics = { "callback" },
}

checkengines = { "luatex" }
checkopts = "--shell-escape --interaction=nonstopmode"
typesetexe = "lualatex"
typesetopts = "--shell-escape --socket --interaction=nonstopmode"
testfiledir = "test/tex"
testsuppdir = "test/tex/supp"

cleanfiles = { "*.log", "*.aux", "*.toc", "*.out" }


if options.target == "compile" then
    compilefennel()
    os.exit(0)
end

if options.target == "unittest" then
    local ok = require("test.kit"):run()
    os.exit(ok and 0 or 1)
end
