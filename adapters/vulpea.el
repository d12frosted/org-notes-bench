;;; vulpea.el --- vulpea adapter -*- lexical-binding: t; -*-

;; Default settings: temp-buffer parsing, no async extraction.
;; https://github.com/d12frosted/vulpea

(defun bench-tool-configure (corpus state)
  (setq org-directory corpus
        vulpea-db-sync-directories (list corpus)
        vulpea-db-location (expand-file-name "vulpea.db" state)
        ;; The corpus uses org-roam's alias property
        vulpea-buffer-alias-property "ROAM_ALIASES")
  (require 'vulpea))

(defun bench-tool-cold-index ()
  ;; Without autosync the scan runs synchronously
  (vulpea-db-sync-full-scan))

(defun bench-tool-persist ()
  ;; The database is on disk already
  nil)

(defun bench-tool-count ()
  (vulpea-db-count-notes))

(defun bench-tool-start ()
  (vulpea-db-autosync-mode 1))

(defun bench-tool-lookup (id)
  (when-let* ((note (vulpea-db-get-by-id id)))
    (vulpea-note-title note)))

(defun bench-tool-backlinks (id)
  (length (vulpea-db-query-by-links-some (list id))))

(defun bench-tool-find-command ()
  #'vulpea-find)

;;; vulpea.el ends here
