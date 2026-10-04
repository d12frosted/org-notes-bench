;;; compare.el --- Medians per tool, corpus and operation -*- lexical-binding: t; -*-

;; Usage: emacs -Q --batch -l aws/compare.el RAW.jsonl
;;
;; One Markdown table per operation, with the median of every round:
;; time until done, total time Emacs was blocked, and the longest
;; single block.  For comparing builds of one tool, where report.el's
;; one-column tables hide the blocked time.

(require 'json)
(require 'subr-x)

(let* ((file (or (car command-line-args-left) (error "Usage: compare.el RAW.jsonl")))
       (rows (with-temp-buffer
               (insert-file-contents file)
               (let (rows)
                 (dolist (line (split-string (buffer-string) "\n" t))
                   (push (json-parse-string line :object-type 'alist) rows))
                 (nreverse rows))))
       (median (lambda (xs)
                 (let ((xs (sort (delq nil (copy-sequence xs)) #'<)))
                   (when xs (nth (/ (length xs) 2) xs)))))
       (fmt (lambda (ms)
              (cond ((null ms) "-")
                    ((< ms 1000) (format "%dms" (round ms)))
                    ((< ms 600000) (format "%.2fs" (/ ms 1000.0)))
                    (t (format "%.1fmin" (/ ms 60000.0))))))
       (keys nil))
  (setq command-line-args-left nil)
  (dolist (row rows)
    (let ((key (list (alist-get 'op row) (alist-get 'corpus row) (alist-get 'tool row))))
      (unless (member key keys) (push key keys))))
  (setq keys (nreverse keys))
  (dolist (op (delete-dups (mapcar #'car keys)))
    (princ (format "\n### %s\n\n| corpus | tool | runs | done | blocked | longest block |\n|---|---|---|---|---|---|\n" op))
    (dolist (key keys)
      (when (equal (car key) op)
        (let* ((group (seq-filter (lambda (row)
                                    (equal (list (alist-get 'op row) (alist-get 'corpus row)
                                                 (alist-get 'tool row))
                                           key))
                                  rows))
               (stat (lambda (field) (funcall median (mapcar (lambda (row) (alist-get field row)) group)))))
          (princ (format "| %s | %s | %d | %s | %s | %s |\n"
                         (nth 1 key) (nth 2 key) (length group)
                         (funcall fmt (funcall stat 'ms))
                         (funcall fmt (funcall stat 'total-block-ms))
                         (funcall fmt (funcall stat 'max-block-ms)))))))))

;;; compare.el ends here
