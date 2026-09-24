;;; install.el --- Install one tool into its own package directory -*- lexical-binding: t; -*-

;; Usage: emacs -Q --batch -l install.el TOOL
;; Installs into .deps/TOOL, so tools never see each other's packages.

(require 'package)
(load (expand-file-name "tools.el" (file-name-directory load-file-name)) nil t)

(let* ((tool (intern (car command-line-args-left)))
       (spec (or (alist-get tool bench-tools)
                 (error "Unknown tool: %s" tool)))
       (root (file-name-directory load-file-name)))
  (setq command-line-args-left nil
        package-user-dir (expand-file-name (format ".deps/%s" tool) root)
        package-archives bench-archives
        package-install-upgrade-built-in nil)
  (package-initialize)
  (package-refresh-contents)
  (dolist (pkg (plist-get spec :packages))
    (unless (package-installed-p pkg)
      (package-install pkg)))
  (when-let* ((vc (plist-get spec :vc)))
    (pcase-let ((`(,name ,url ,rev) vc))
      (unless (package-installed-p name)
        (package-vc-install (list name :url url :branch nil) rev))))
  (message "Installed %s into %s" tool package-user-dir))
