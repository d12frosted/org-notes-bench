;;; hyrolo-native.el --- HyRolo adapter, its own search -*- lexical-binding: t; -*-

;; GNU Hyperbole's HyRolo without Consult: `hyrolo-fgrep' searches
;; the files of `hyrolo-file-list' in Emacs and collects the matching
;; entries, each with its sub-entries, in the HyRolo match buffer.
;; It visits every file to do so and keeps the buffers, so the first
;; search of a session reads the whole collection.
;; https://www.gnu.org/software/hyperbole/

(defvar bench-hyrolo-notes nil)

(defun bench-tool-configure (corpus _state)
  (setq bench-hyrolo-notes (expand-file-name "notes" corpus)))

(defun bench-tool-start ()
  (require 'hyrolo)
  ;; The manual has `hyrolo-file-list' customized.  Setting it expands
  ;; the directory into its files, so that is part of starting up
  (customize-set-variable 'hyrolo-file-list (list bench-hyrolo-notes)))

(defun bench-tool-search (string)
  ;; Retrieve the entries without displaying the match buffer; the
  ;; value is the number of entries matched
  (hyrolo-fgrep string nil nil nil nil t))

;;; hyrolo-native.el ends here
