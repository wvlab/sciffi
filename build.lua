module = "sciffi"
tdsroot = "luatex"

installfiles = {
    "sciffi.sty",
    "sciffi-python.sty",
    "sciffi-cosmo.lua",
    "sciffi-python-matplotlib.sty",
    "sciffi-base.lua",
    "sciffi-python.lua",
    "sciffi-python-matplotlib.lua",
}

docfiles = {
    "doc/*"
}

sourcefiles = {
    "src/*",
    "build.lua",
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


if options.target == "check" then
    local a = require("test.kit")
    print(a)
end
