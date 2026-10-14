;;; org-ql.el --- org-ql adapter, its regexp search -*- lexical-binding: t; -*-

;; org-ql queries Org files without an index of its own: it visits
;; each file, keeps the buffer, and looks through the headings.  A
;; search for text is its `regexp' predicate, run over the Org files
;; of `org-directory' as `org-ql-search' lists them.
;; https://github.com/alphapapa/org-ql
;;
;; org-ql looks at headings.  The text before a file's first heading
;; is not an entry, so what is written there is not found.

(defun bench-tool-configure (corpus _state)
  (setq org-directory (expand-file-name "notes" corpus)
        ;; The notes are in subdirectories
        org-ql-search-directories-files-recursive t))

(defun bench-tool-start ()
  (require 'org-ql)
  (require 'org-ql-search))

(defun bench-tool-search (string)
  ;; The entries whose text matches, as org-ql returns them
  (length (org-ql-select (org-ql-search-directories-files)
            `(regexp ,(regexp-quote string)))))

;;; org-ql.el ends here
