#!/usr/bin/env bb
;; Entry point: `bb extensions/bin/clojars-stats.bb [--feed N]` from anywhere,
;; or `bb run [--feed N]` from this dir. Exits 1 if an adoption signal fires.
(require '[babashka.classpath :as cp] '[babashka.fs :as fs])
(cp/add-classpath (str (fs/parent *file*) "/src"))
(require '[clojars-stats])
(apply clojars-stats/-main *command-line-args*)
