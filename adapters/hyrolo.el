;;; hyrolo.el --- HyRolo adapter, search through Consult -*- lexical-binding: t; -*-

;; GNU Hyperbole's HyRolo with Consult and ripgrep installed, which is
;; how its author suggests using it on a large collection.  HyRolo
;; keeps no index: `hyrolo-file-list' names the directory, and
;; `hyrolo-consult-fgrep' searches it for a string by handing a
;; ripgrep command to Consult.
;; https://www.gnu.org/software/hyperbole/
;;
;; A batch Emacs cannot show Consult's matches, so the search is run
;; as `bench-consult-grep-command' describes: HyRolo's own ripgrep
;; command line, started and read by Emacs.

(defvar bench-hyrolo-notes nil)

(defun bench-tool-configure (corpus _state)
  (setq bench-hyrolo-notes (expand-file-name "notes" corpus)))

(defun bench-tool-start ()
  (require 'hyrolo)
  (require 'consult)
  ;; The manual has `hyrolo-file-list' customized.  Setting it expands
  ;; the directory into its files, so that is part of starting up
  (customize-set-variable 'hyrolo-file-list (list bench-hyrolo-notes)))

(defun bench-tool-search (string)
  (let ((search (bench-consult-grep-command
                 (lambda () (hyrolo-consult-fgrep string)))))
    ;; One line of output per matching line
    (bench-run-process (car search) (cdr search))))

;;; hyrolo.el ends here
