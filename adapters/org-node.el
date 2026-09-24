;;; org-node.el --- org-node (org-mem) adapter -*- lexical-binding: t; -*-

;; Default settings, set up as org-node's README recommends: both
;; `org-node-cache-mode' and `org-mem-updater-mode'.  Org-mem keeps
;; nothing on disk, so every session builds its cache from scratch;
;; `warm' is therefore a full index too, by design.
;; https://github.com/meedstrom/org-node

(defun bench-tool-configure (corpus _state)
  (setq org-directory corpus
        org-mem-watch-dirs (list corpus))
  (require 'org-node)
  (require 'org-mem-updater))

(defun bench-tool-start ()
  (org-node-cache-mode 1)
  (org-mem-updater-mode 1))

(defun bench-tool-cold-index ()
  (bench-tool-start)
  (org-mem-await "bench" 3600))

(defun bench-tool-persist ()
  nil)

(defun bench-tool-count ()
  (length (org-mem-all-id-nodes)))

(defun bench-tool-lookup (id)
  (when-let* ((entry (org-mem-entry-by-id id)))
    (org-mem-entry-title entry)))

(defun bench-tool-backlinks (id)
  ;; Links are per occurrence; count the notes they come from
  (length (seq-uniq (mapcar #'org-mem-link-nearby-id
                            (org-mem-id-links-to-id id)))))

(defun bench-tool-find-command ()
  #'org-node-find)

;;; org-node.el ends here
