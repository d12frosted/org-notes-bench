;;; supertag.el --- Supertag adapter -*- lexical-binding: t; -*-

;; Default settings.  Loading the package initializes it: the store
;; is read from disk, timers are set up and auto-sync is scheduled.
;; That makes `require' Supertag's startup, so it is timed in `warm'.
;; https://github.com/yibie/supertag

(defun bench-tool-configure (corpus state)
  ;; Must be set before the package loads
  (setq org-directory corpus
        supertag-sync-directories (list corpus)
        supertag-data-directory (expand-file-name "supertag/" state)))

(defun bench-tool-start ()
  (require 'supertag)
  (unless (bound-and-true-p supertag--initialized)
    (supertag-init)))

(defun bench-tool-cold-index ()
  (bench-tool-start)
  (supertag-sync-full-rescan))

(defun bench-tool-persist ()
  (supertag-save-store))

(defun bench-tool-count ()
  (hash-table-count (supertag-store-get-collection :nodes)))

(defun bench-tool-lookup (id)
  (when-let* ((node (supertag-node-get id)))
    (plist-get node :title)))

(defun bench-tool-backlinks (id)
  ;; One item per source note
  (length (supertag-reference-service-backlinks id)))

(defun bench-tool-find-command ()
  #'supertag-find-node)

;;; supertag.el ends here
