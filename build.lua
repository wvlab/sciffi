module = "sciffi"
tdsroot = "luatex"

installfiles = {
    "sciffi.sty",
    "sciffi-python.sty",
    "sciffi-base.lua",
    "sciffi-python.lua",
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
    topics = { "macro-pkg" },
}

checkengines = { "luatex" }
checkconfigs = {}

cleanfiles = { "*.log", "*.aux", "*.toc", "*.out" }
