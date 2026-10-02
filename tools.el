;;; tools.el --- Pinned versions of the benchmarked tools -*- lexical-binding: t; -*-

;; Each entry: (TOOL . PLIST)
;;   :packages  packages to install from the archives below (with deps)
;;   :vc        (NAME URL REV) packages installed from git at REV
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
              :vc (supertag "https://github.com/yibie/supertag"
                            "3cae90ec8a8a815a2a07f00e3f7c8a4ced24e534"))
    (vulpea :adapter vulpea :packages (vulpea))
    ;; vulpea with the settings its README recommends for speed
    (vulpea-tuned :adapter vulpea-tuned :packages (emacsql s dash)
                  :vc (vulpea "https://github.com/d12frosted/vulpea"
                              "8e70ec07bcf665062535addb17db3b5b86331622"))
    (vulpea-master :adapter vulpea :packages (emacsql s dash)
                   :vc (vulpea "https://github.com/d12frosted/vulpea"
                               "8e70ec07bcf665062535addb17db3b5b86331622"))))

(provide 'tools)
;;; tools.el ends here
