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
    ;; save runs from before harness 3 measured show-paren or a stale file,
    ;; backlinks runs from before harness 4 a median of 5
    (when (and (member (report-version row)
                       (list nil (gethash (report-get row 'tool) latest)))
               (let ((op (or (report-get row 'op) ""))
                     (harness (or (report-get row 'harness) 1)))
                 (not (or (and (string-prefix-p "save" op) (< harness 3))
                          (and (equal op "backlinks") (< harness 4))))))
      (push row (alist-get (list (report-get row 'tool)
                                 (report-get row 'corpus)
                                 (report-get row 'op))
                           groups nil nil #'equal))))
  (let* ((only (when-let* ((env (getenv "REPORT_TOOLS"))) (split-string env)))
         (all-tools (seq-filter (lambda (tool) (or (null only) (member tool only)))
                                (seq-uniq (mapcar (lambda (r) (report-get r 'tool)) rows))))
         ;; `search' has tables of its own, for the tools that ran it.
         ;; A tool without an index ran nothing else and is left out of
         ;; the other tables
         (runs-p (lambda (tool search)
                   (seq-some (lambda (r) (and (equal (report-get r 'tool) tool)
                                              (eq search (equal (report-get r 'op) "search"))))
                             rows)))
         (search-tools (seq-filter (lambda (tool) (funcall runs-p tool t)) all-tools))
         (tools (seq-filter (lambda (tool) (funcall runs-p tool nil)) all-tools))
         ;; In the tables of the other operations, a tool without an index
         ;; shows that it has none, and its start-up as its warm start.
         ;; Plain ripgrep, which is no package, stays in the search tables
         (package-p (lambda (tool)
                      (consp (report-get (seq-find (lambda (r) (equal (report-get r 'tool) tool)) rows)
                                         'versions))))
         (index-free (seq-filter package-p (seq-difference search-tools tools)))
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
    (dolist (tool (seq-difference search-tools tools))
      ;; The packages of a tool that only searches
      (let ((versions (report-get (seq-find (lambda (r) (equal (report-get r 'tool) tool)) rows)
                                  'versions)))
        (princ (format "- %s: %s\n" tool
                       (if (consp versions)
                           (mapconcat (lambda (v) (format "%s %s" (car v) (cdr v))) versions ", ")
                         "no package")))))
    (let ((sizes (mapcar (lambda (c) (substring c 7)) corpora)))
      (dolist (spec '(("Cold index (synchronous, nothing else running)" "cold" ms)
                      ("First run on an empty index, until every note is indexed" "first-run" ms)
                      ("First run: longest freeze while indexing" "first-run" max-block-ms)
                      ("Warm start, until a note can be looked up" "warm" ms)
                      ("Open the find command (until the minibuffer)" "find" ms)
                      ("Backlinks of the hub note, first call" "backlinks" first-ms)
                      ("Backlinks of the hub note, mean of 10 later calls" "backlinks" ms)))
        (report-table (car spec) (cons "tool" sizes)
                      (mapcar (lambda (tool)
                                (cons tool
                                      (mapcar (lambda (c)
                                                (if (member tool index-free)
                                                    (pcase (nth 1 spec)
                                                      ((or "cold" "first-run") "no index")
                                                      ("warm" (report-fmt-ms (funcall stat tool c "search" 'start-ms)))
                                                      (_ "-"))
                                                (let ((value (funcall stat tool c (nth 1 spec) (nth 2 spec)))
                                                      (stopped (or (funcall stat tool c (nth 1 spec) 'stopped-after-ms)
                                                                   (funcall stat tool c "cold" 'stopped-after-ms))))
                                                  (cond (value (report-fmt-ms value))
                                                        (stopped (format "not done after %s"
                                                                         (report-fmt-ms stopped)))
                                                        (t "-")))))
                                              corpora)))
                              (append tools index-free)))))
    (report-table "Saving a large file (1k-note corpus)"
                  '("tool" "1MB longest freeze" "1MB until findable"
                    "10MB longest freeze" "10MB until findable")
                  (append
                   (mapcar (lambda (tool)
                            (list tool
                                  (report-fmt-ms (funcall stat tool "corpus-save" "save-1mb" 'max-block-ms))
                                  (report-fmt-ms (funcall stat tool "corpus-save" "save-1mb" 'ms))
                                  (report-fmt-ms (funcall stat tool "corpus-save" "save-10mb" 'max-block-ms))
                                  (report-fmt-ms (funcall stat tool "corpus-save" "save-10mb" 'ms))))
                          tools)
                   ;; Nothing to update on save: the next search reads the file
                   (mapcar (lambda (tool) (list tool "no index" "no index" "no index" "no index"))
                           index-free)))
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
                          tools))
    (when search-tools
      (let ((sizes (mapcar (lambda (c) (substring c 7)) corpora)))
        (dolist (spec '(("Text search: starting up" start-ms)
                        ("Text search: first search of a session" first-ms)
                        ("Text search: one note by its ID" one-ms)
                        ("Text search: every line that links to the hub" hub-ms)))
          (report-table (car spec) (cons "tool" sizes)
                        (mapcar (lambda (tool)
                                  (cons tool
                                        (mapcar (lambda (c)
                                                  (report-fmt-ms (funcall stat tool c "search" (nth 1 spec))))
                                                corpora)))
                                search-tools)))
        (report-table "Text search: what each tool matched"
                      (cons "tool" (append (mapcar (lambda (c) (concat "one " (substring c 7))) corpora)
                                           (mapcar (lambda (c) (concat "hub " (substring c 7))) corpora)))
                      (mapcar (lambda (tool)
                                (cons tool
                                      (append
                                       (mapcar (lambda (c) (format "%s" (or (funcall stat tool c "search" 'one-matches) "-"))) corpora)
                                       (mapcar (lambda (c) (format "%s" (or (funcall stat tool c "search" 'hub-matches) "-"))) corpora))))
                              search-tools))))))

;;; report.el ends here
