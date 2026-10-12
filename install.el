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
  ;; Development snapshots from GNU ELPA go in first and on their own,
  ;; so that no other package comes from there
  (when-let* ((devel (plist-get spec :devel)))
    (let ((package-archives '(("gnu-devel" . "https://elpa.gnu.org/devel/"))))
      (package-refresh-contents)
      (dolist (pkg devel)
        (unless (package-installed-p pkg)
          (package-install pkg)))))
  (package-refresh-contents)
  (dolist (pkg (plist-get spec :packages))
    (unless (package-installed-p pkg)
      (package-install pkg)))
  ;; Git dependencies that no archive serves go in first
  (dolist (dep (plist-get spec :vc-deps))
    (pcase-let ((`(,name ,url ,rev) dep))
      (unless (package-installed-p name)
        (package-vc-install (list name :url url :branch nil) rev))))
  (when-let* ((vc (plist-get spec :vc)))
    (pcase-let ((`(,name ,url ,rev) vc))
      (unless (package-installed-p name)
        (package-vc-install (list name :url url :branch nil) rev))
      ;; package-vc reports success even when a dependency is missing and
      ;; the package cannot be activated; fail here, not mid-benchmark
      (unless (locate-library (symbol-name name))
        (error "%s installed but cannot be loaded (missing dependency?)" name))))
  (message "Installed %s into %s" tool package-user-dir))
