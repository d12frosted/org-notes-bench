;;; corpus.el --- Deterministic corpus of org notes -*- lexical-binding: t; -*-

;; Usage: emacs -Q --batch -l corpus.el DIR N [big]
;;
;; Writes N note files under DIR/notes (100 per subdirectory), and with
;; `big' also two large files under DIR/big (1MB and 10MB) for the save
;; benchmarks.  The random state is
;; seeded, so the same N always produces the same bytes.
;;
;; Every note is an org-id note in the form org-roam, org-node,
;; Supertag and vulpea all read: a file-level :ID: drawer, #+title,
;; #+filetags, a few paragraphs with id: links to earlier notes, and a
;; few headings, some of which carry their own :ID:.  Note 0 is a hub:
;; about a fifth of all notes link to it, for the backlinks benchmark.

(require 'cl-lib)

(defconst corpus-words
  (split-string "lorem ipsum dolor sit amet consectetur adipiscing elit sed do
eiusmod tempor incididunt ut labore et dolore magna aliqua enim ad minim veniam
quis nostrud exercitation ullamco laboris nisi aliquip ex ea commodo consequat
duis aute irure in reprehenderit voluptate velit esse cillum fugiat nulla
pariatur excepteur sint occaecat cupidatat non proident sunt culpa qui officia
deserunt mollit anim id est laborum"))

(defconst corpus-tags
  '("project" "area" "resource" "person" "book" "idea" "wine" "emacs" "draft"))

(defun corpus--pick (list) (nth (random (length list)) list))

(defun corpus--words (n)
  (mapconcat (lambda (_) (corpus--pick corpus-words)) (number-sequence 1 n) " "))

(defun corpus--title ()
  (capitalize (corpus--words (+ 2 (random 4)))))

(defun corpus--id ()
  (format "%08x-%04x-4%03x-%04x-%012x"
          (random (expt 16 8)) (random (expt 16 4)) (random (expt 16 3))
          (logior #x8000 (random #x4000)) (random (expt 16 12))))

(defun corpus--link (notes)
  (let ((target (corpus--pick notes)))
    (format "[[id:%s][%s]]" (car target) (cdr target))))

(defun corpus--paragraph (notes hub)
  "Return a paragraph, maybe with links to NOTES (and HUB)."
  (let ((parts (list (corpus--words (+ 20 (random 30))))))
    (when notes
      (dotimes (_ (random 3))
        (push (corpus--link notes) parts)
        (push (corpus--words (+ 3 (random 10))) parts)))
    (when (and hub (zerop (random 5)))
      (push (format "See [[id:%s][%s]]." (car hub) (cdr hub)) parts))
    (mapconcat #'identity (nreverse parts) " ")))

(defun corpus--note (id title notes hub)
  "Return the text of note ID with TITLE linking into NOTES."
  (with-temp-buffer
    (insert ":PROPERTIES:\n"
            (format ":ID:       %s\n" id))
    (when (zerop (random 5))
      (insert (format ":ROAM_ALIASES: \"%s\"\n" (corpus--title))))
    (insert ":END:\n"
            (format "#+title: %s\n" title)
            (format "#+filetags: :%s:\n\n"
                    (mapconcat #'identity
                               (seq-uniq (list (corpus--pick corpus-tags)
                                               (corpus--pick corpus-tags)))
                               ":")))
    (dotimes (_ (1+ (random 3)))
      (insert (corpus--paragraph notes hub) "\n\n"))
    (dotimes (_ (random 4))
      (insert (format "* %s\n" (corpus--title)))
      (when (< (random 10) 3)
        (insert ":PROPERTIES:\n" (format ":ID:       %s\n" (corpus--id)) ":END:\n"))
      (insert (corpus--paragraph notes nil) "\n\n"))
    (buffer-string)))

(defun corpus--big (path bytes notes)
  "Write one file of about BYTES at PATH: many headings, 30% with IDs."
  (with-temp-buffer
    (insert ":PROPERTIES:\n" (format ":ID:       %s\n" (corpus--id)) ":END:\n"
            (format "#+title: Big %s\n\n" (file-name-base path)))
    (while (< (buffer-size) bytes)
      (insert (format "* %s\n" (corpus--title)))
      (when (< (random 10) 3)
        (insert ":PROPERTIES:\n" (format ":ID:       %s\n" (corpus--id)) ":END:\n"))
      (insert (corpus--paragraph notes nil) "\n\n"))
    (write-region (point-min) (point-max) path nil 'silent)))

(defun corpus-generate (dir n &optional big)
  "Generate N notes under DIR, and the large files when BIG."
  (random (format "org-notes-bench-%d" n))
  (let ((notes-dir (expand-file-name "notes" dir))
        (big-dir (expand-file-name "big" dir))
        (notes nil)
        hub)
    (make-directory notes-dir t)
    (dotimes (i n)
      (let* ((id (corpus--id))
             (title (format "%s %d" (corpus--title) i))
             (sub (expand-file-name (format "%03d" (/ i 100)) notes-dir))
             (path (expand-file-name (format "note-%06d.org" i) sub)))
        (make-directory sub t)
        (write-region (corpus--note id title
                                    ;; link among a window of earlier notes
                                    (seq-take notes 200) hub)
                      nil path nil 'silent)
        (push (cons id title) notes)
        (unless hub (setq hub (cons id title)))))
    (when big
      (make-directory big-dir t)
      (corpus--big (expand-file-name "big-1mb.org" big-dir) (* 1024 1024) (seq-take notes 200))
      (corpus--big (expand-file-name "big-10mb.org" big-dir) (* 10 1024 1024) (seq-take notes 200)))
    (with-temp-file (expand-file-name "corpus.eld" dir)
      (prin1 (list :n n :hub-id (car hub) :hub-title (cdr hub)) (current-buffer)))
    (message "Generated %d notes in %s (hub %s)" n dir (car hub))))

(when (and noninteractive command-line-args-left)
  (let ((dir (expand-file-name (pop command-line-args-left)))
        (n (string-to-number (pop command-line-args-left)))
        (big (equal (pop command-line-args-left) "big")))
    (corpus-generate dir n big)))

(provide 'corpus)
;;; corpus.el ends here
