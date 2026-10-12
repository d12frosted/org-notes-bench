;;; ripgrep.el --- Plain ripgrep, for reference in `search' -*- lexical-binding: t; -*-

;; No package at all: Emacs starts `rg' on the notes directory and
;; reads the matching lines it prints.  Next to a tool that runs
;; ripgrep for its search, it shows how much of that tool's time is
;; ripgrep's.

(defvar bench-ripgrep-notes nil)

(defun bench-tool-configure (corpus _state)
  (setq bench-ripgrep-notes (expand-file-name "notes" corpus)))

(defun bench-tool-start ())

(defun bench-tool-search (string)
  ;; One line of output per matching line
  (bench-run-process (list "rg" "--line-number" "--fixed-strings" "-e" string ".")
                     bench-ripgrep-notes))

;;; ripgrep.el ends here
