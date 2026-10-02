;;; report.el --- Summarize results/raw.jsonl as Markdown tables -*- lexical-binding: t; -*-

;; Usage: emacs -Q --batch -l report.el [RAW.jsonl]
;;
;; REPORT_TOOLS (space separated) limits the report to those tools.
;;
;; Groups runs by tool, corpus and operation and reports the median of
;; each group.  Only the most recent version of each tool counts: runs
;; recorded against older versions are skipped.

(require 'cl-lib)
(require 'json)
(require 'subr-x)

(defconst report-root (file-name-directory (or load-file-name buffer-file-name)))

(defun report-read (file)
  (with-temp-buffer
    (insert-file-contents file)
    (let (rows)
      (goto-char (point-min))
      (while (not (eobp))
        (let ((line (buffer-substring (point) (line-end-position))))
          (unless (string-blank-p line)
            (push (json-parse-string line :object-type 'alist) rows)))
        (forward-line 1))
      (nreverse rows))))

(defun report-get (row key) (alist-get key row))

(defun report-version (row)
  "The version string that identifies ROW's tool build."
  (let* ((tool (report-get row 'tool))
         (versions (report-get row 'versions))
         (main (pcase tool
                 ((or "org-roam" "org-node" "vulpea") (intern tool))
                 (_ nil))))
    (or (report-get row 'revision)
        (and main (alist-get main versions)))))

(defun report-median (xs)
  (let ((xs (sort (copy-sequence (delq nil xs)) #'<)))
    (when xs (nth (/ (length xs) 2) xs))))

(defun report-fmt-ms (ms)
  (cond ((null ms) "-")
        ((< ms 1) (format "%.1fms" ms))
        ((< ms 1000) (format "%dms" (round ms)))
        ((< ms 60000) (format "%.1fs" (/ ms 1000.0)))
        (t (format "%.1fmin" (/ ms 60000.0)))))

(defun report-table (title header rows)
  (princ (format "\n### %s\n\n" title))
  (princ (concat "| " (string-join header " | ") " |\n"))
  (princ (concat "|" (mapconcat (lambda (_) "---") header "|") "|\n"))
  (dolist (row rows)
    (princ (concat "| " (string-join row " | ") " |\n"))))

(let* ((file (or (car command-line-args-left)
                 (expand-file-name "results/raw.jsonl" report-root)))
       (rows (report-read file))
       (latest (make-hash-table :test #'equal))
       groups)
  (setq command-line-args-left nil)
  ;; Most recent version per tool
  (dolist (row rows)
    (when-let* ((version (report-version row)))
      (puthash (report-get row 'tool) version latest)))
  (dolist (row rows)
    ;; Rows without versions (runs the watchdog stopped) count as latest;
    ;; save runs from before harness 3 measured show-paren or a stale file
    (when (and (member (report-version row)
                       (list nil (gethash (report-get row 'tool) latest)))
               (not (and (string-prefix-p "save" (or (report-get row 'op) ""))
                         (< (or (report-get row 'harness) 1) 3))))
      (push row (alist-get (list (report-get row 'tool)
                                 (report-get row 'corpus)
                                 (report-get row 'op))
                           groups nil nil #'equal))))
  (let* ((only (when-let* ((env (getenv "REPORT_TOOLS"))) (split-string env)))
         (tools (seq-filter (lambda (tool) (or (null only) (member tool only)))
                            (seq-uniq (mapcar (lambda (r) (report-get r 'tool)) rows))))
         (corpora (sort (seq-uniq
                         (delq nil (mapcar (lambda (r)
                                             (let ((c (report-get r 'corpus)))
                                               (unless (equal c "corpus-save") c)))
                                           rows)))
                        (lambda (a b) (< (string-to-number (substring a 7))
                                         (string-to-number (substring b 7))))))
         (stat (lambda (tool corpus op key)
                 (report-median
                  (mapcar (lambda (r) (report-get r key))
                          (alist-get (list tool corpus op) groups nil nil #'equal))))))
    (princ "## Versions\n\n")
    (dolist (tool tools)
      (princ (format "- %s: %s\n" tool (gethash tool latest))))
    (let ((sizes (mapcar (lambda (c) (substring c 7)) corpora)))
      (dolist (spec '(("Cold index (synchronous, nothing else running)" "cold" ms)
                      ("First run on an empty index, until every note is indexed" "first-run" ms)
                      ("First run: longest freeze while indexing" "first-run" max-block-ms)
                      ("Warm start, until a note can be looked up" "warm" ms)
                      ("Open the find command (until the minibuffer)" "find" ms)
                      ("Backlinks of the hub note, first call" "backlinks" first-ms)
                      ("Backlinks of the hub note, median of 5" "backlinks" ms)))
        (report-table (car spec) (cons "tool" sizes)
                      (mapcar (lambda (tool)
                                (cons tool
                                      (mapcar (lambda (c)
                                                (let ((value (funcall stat tool c (nth 1 spec) (nth 2 spec)))
                                                      (stopped (or (funcall stat tool c (nth 1 spec) 'stopped-after-ms)
                                                                   (funcall stat tool c "cold" 'stopped-after-ms))))
                                                  (cond (value (report-fmt-ms value))
                                                        (stopped (format "not done after %s"
                                                                         (report-fmt-ms stopped)))
                                                        (t "-"))))
                                              corpora)))
                              tools))))
    (report-table "Saving a large file (1k-note corpus)"
                  '("tool" "1MB longest freeze" "1MB until findable"
                    "10MB longest freeze" "10MB until findable")
                  (mapcar (lambda (tool)
                            (list tool
                                  (report-fmt-ms (funcall stat tool "corpus-save" "save-1mb" 'max-block-ms))
                                  (report-fmt-ms (funcall stat tool "corpus-save" "save-1mb" 'ms))
                                  (report-fmt-ms (funcall stat tool "corpus-save" "save-10mb" 'max-block-ms))
                                  (report-fmt-ms (funcall stat tool "corpus-save" "save-10mb" 'ms))))
                          tools))
    (report-table "Sanity: what each tool counted"
                  (cons "tool" (append (mapcar (lambda (c) (concat "notes " (substring c 7))) corpora)
                                       (mapcar (lambda (c) (concat "candidates " (substring c 7))) corpora)
                                       (mapcar (lambda (c) (concat "backlinks " (substring c 7))) corpora)))
                  (mapcar (lambda (tool)
                            (cons tool
                                  (append
                                   (mapcar (lambda (c) (format "%s" (or (funcall stat tool c "cold" 'indexed) "-"))) corpora)
                                   (mapcar (lambda (c) (format "%s" (or (funcall stat tool c "find" 'candidates) "-"))) corpora)
                                   (mapcar (lambda (c) (format "%s" (or (funcall stat tool c "backlinks" 'sources) "-"))) corpora))))
                          tools))))

;;; report.el ends here
