;;; vulpea-tuned.el --- vulpea with its recommended speed settings -*- lexical-binding: t; -*-

;; The "Best performance" settings from vulpea's README: the worker
;; also writes the database (`full'), indexing skips org-mode-hook, and
;; only bracketed links are indexed.
;; https://github.com/d12frosted/vulpea#best-performance

(load (expand-file-name "vulpea.el" (file-name-directory load-file-name)) nil t)

(advice-add 'bench-tool-configure :after
            (lambda (&rest _)
              (setq vulpea-db-async-extraction 'full
                    vulpea-db-parse-method 'single-temp-buffer
                    vulpea-db-index-plain-links nil)))

;;; vulpea-tuned.el ends here
