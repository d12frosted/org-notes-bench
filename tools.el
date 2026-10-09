;;; tools.el --- Pinned versions of the benchmarked tools -*- lexical-binding: t; -*-

;; Each entry: (TOOL . PLIST)
;;   :packages  packages to install from the archives below (with deps)
;;   :vc        (NAME URL REV) packages installed from git at REV
;;   :vc-deps   ((NAME URL REV) ...) git dependencies installed before :vc
;;   :adapter   file in adapters/ implementing the bench-tool-* functions
;; Archive installs take the version the archive currently serves;
;; the installed versions are recorded with every result.

(defconst bench-archives
  '(("gnu" . "https://elpa.gnu.org/packages/")
    ("nongnu" . "https://elpa.nongnu.org/nongnu/")
    ("melpa-stable" . "https://stable.melpa.org/packages/")))

(defconst bench-tools
  '((org-roam :adapter org-roam :packages (org-roam))
    (org-node :adapter org-node :packages (org-node org-mem))
    (supertag :adapter supertag :packages (ht)
              :vc-deps ((textui "https://github.com/yibie/textui"
                                "8b3010d0f251b52dd1867c741d18bf66e405922d"))
              :vc (supertag "https://github.com/yibie/supertag"
                            "dcd3dc25df9c603385e70f425395d53120d9e4b4"))
    (vulpea :adapter vulpea :packages (vulpea))
    ;; vulpea with the settings its README recommends for speed
    (vulpea-tuned :adapter vulpea-tuned :packages (emacsql s dash)
                  :vc (vulpea "https://github.com/d12frosted/vulpea"
                              "d9be36367be3d91fa964756c6425309a034cc3b2"))
    (vulpea-master :adapter vulpea :packages (emacsql s dash)
                   :vc (vulpea "https://github.com/d12frosted/vulpea"
                               "d9be36367be3d91fa964756c6425309a034cc3b2"))))

(provide 'tools)
;;; tools.el ends here
