require("sciffi-base")

local header = [[
# start:sciffi-python-matplotlib header
import sys
import matplotlib as mpl
mpl.use("pgf")
import matplotlib.pyplot as plt
def savefig(fig: plt.Figure | None = None) -> None:
    if fig is None:
        return plt.savefig(sys.stdout.buffer, format="pgf")
    return fig.savefig(sys.stdout.buffer, format="pgf")
# end:sciffi-python-matplotlib header
]]

sciffi.interpretators["python-matplotlib"] = {
    execute_snippet = function(code, options)
        sciffi.interpretators.python.execute_snippet(header .. sciffi.helpers.deindent(code), options)
    end,
    execute_script = function(filepath, options)
        sciffi.helpers.print([[
            \ExplSyntaxOn
            \msg_error:nnn {sciffi-python-matplotlib}{use-python-interpretator}
            \ExplSyntaxOff
        ]])
    end
}
