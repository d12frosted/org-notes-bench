;;; org-roam.el --- org-roam adapter -*- lexical-binding: t; -*-

;; Default settings.
;; https://github.com/org-roam/org-roam

(defun bench-tool-configure (corpus state)
  (setq org-directory corpus
        org-roam-directory corpus
        org-roam-db-location (expand-file-name "org-roam.db" state)
        org-roam-v2-ack t)
  (require 'org-roam))

(defun bench-tool-cold-index ()
  (org-roam-db-sync))

(defun bench-tool-persist ()
  ;; The database is on disk already
  nil)

(defun bench-tool-count ()
  (caar (org-roam-db-query [:select (funcall count *) :from nodes])))

(defun bench-tool-start ()
  (org-roam-db-autosync-mode 1))

(defun bench-tool-lookup (id)
  (when-let* ((node (org-roam-node-from-id id)))
    (org-roam-node-title node)))

(defun bench-tool-backlinks (id)
  (length (org-roam-backlinks-get (org-roam-node-from-id id) :unique t)))

(defun bench-tool-find-command ()
  #'org-roam-node-find)

;;; org-roam.el ends here
