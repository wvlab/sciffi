(local sciffi (require :sciffi-base))

; TODO: add docstrings and type annotations

; So users are able to use fennel itself
(. (include :..tools.fennel) :install)
(local fennel (require :..tools.fennel))
(set package.preload.fennel (fn [] fennel))
(tset package.preload :..tools.fennel nil)

(fn execute_snippet [code options] 
    ""
    (fennel.eval code (sciffi.helpers.parse_options options)))

(fn execute_script [filepath options] 
    ""
    (fennel.dofile filepath (sciffi.helpers.parse_options options)))

(local fennel-interpretator
    {: fennel
     : execute_snippet
     : execute_script})

(set sciffi.interpretators.fennel fennel-interpretator)

fennel-interpretator
