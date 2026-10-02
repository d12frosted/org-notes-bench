;;; bench.el --- Run one benchmark operation for one tool -*- lexical-binding: t; -*-

;; Usage: emacs -Q --batch -l bench.el TOOL CORPUS OP
;;
;; TOOL    a key of `bench-tools' (tools.el); its packages live in .deps/TOOL
;; CORPUS  a directory made by corpus.el
;; OP      cold | first-run | warm | find | backlinks | save-1mb | save-10mb
;;
;; Each run is a fresh Emacs.  The tool's state (database, caches,
;; org-id locations, even `user-emacs-directory') lives in
;; data/state/TOOL/CORPUS-NAME, so tools never share anything.
;; `cold' and `first-run' delete that state first and build it; every
;; other operation starts from the state the last one left behind.
;;
;; One JSON line per run is appended to results/raw.jsonl.

(require 'cl-lib)
(require 'json)
(require 'package)

(defconst bench-root (file-name-directory (or load-file-name buffer-file-name)))
(load (expand-file-name "tools.el" bench-root) nil t)

;;; Measuring

(defun bench-now () (float-time))

(defmacro bench-time (&rest body)
  "Run BODY, return (SECONDS . VALUE)."
  (declare (indent 0))
  `(let ((t0 (bench-now)))
     (let ((value (progn ,@body)))
       (cons (- (bench-now) t0) value))))

(defun bench-idle-until (pred timeout)
  "Let Emacs run its timers and processes until PRED holds, as if idle.

Behaves like a user who stopped typing: regular timers and process
output are handled by `accept-process-output', and idle timers are
run by hand once their idle delay has passed (batch Emacs never
becomes idle on its own).  Each idle timer runs at most once, as in
one real idle period.

Returns a plist: :done (PRED held), :wall seconds, :max-block (the
longest stretch Emacs could not have answered a keystroke) and
:total-block (all such time added up)."
  (let ((start (bench-now))
        (fired nil)
        (max-block 0.0)
        (total-block 0.0)
        (done nil)
        (slice 0.01))
    (cl-flet ((block (seconds)
                (when (> seconds 0)
                  (setq max-block (max max-block seconds)
                        total-block (+ total-block seconds)))))
      (while (and (not (setq done (funcall pred)))
                  (< (- (bench-now) start) timeout))
        (let ((t0 (bench-now)))
          (accept-process-output nil slice)
          (block (- (bench-now) t0 slice)))
        (dolist (timer (copy-sequence timer-idle-list))
          (when (and (not (memq timer fired))
                     (>= (- (bench-now) start)
                         (float-time (timer--time timer))))
            (push timer fired)
            (let ((t0 (bench-now)))
              (timer-event-handler timer)
              (block (- (bench-now) t0)))))))
    (list :done (and done t)
          :wall (- (bench-now) start)
          :max-block max-block
          :total-block total-block)))

(defun bench-settle (seconds)
  "Let background work run for SECONDS, untimed."
  (bench-idle-until #'ignore seconds))

;;; Environment

(defvar bench-tool nil)
(defvar bench-corpus nil)
(defvar bench-corpus-info nil)
(defvar bench-state nil)
(defvar bench-result nil
  "Plist the operation fills in; written out at the end.")

(defun bench-put (key value)
  (setq bench-result (plist-put bench-result key value)))

(defun bench-package-versions ()
  "Alist of installed package versions."
  (mapcar (lambda (entry)
            (cons (car entry)
                  (package-version-join (package-desc-version (cadr entry)))))
          package-alist))

(defun bench-vc-revision (name)
  "Git revision of the vc-installed package NAME, or nil."
  (let ((dir (expand-file-name (symbol-name name) package-user-dir)))
    (when (file-directory-p (expand-file-name ".git" dir))
      (let ((default-directory dir))
        (string-trim (shell-command-to-string "git rev-parse --short HEAD"))))))

(defun bench-write-result ()
  (let* ((spec (alist-get bench-tool bench-tools))
         (vc (plist-get spec :vc))
         (line (append
                (list :tool (symbol-name bench-tool)
                      :corpus (file-name-nondirectory (directory-file-name bench-corpus))
                      :notes (plist-get bench-corpus-info :n)
                      :time (format-time-string "%FT%T%z")
                      :emacs emacs-version
                      :org (org-version)
                      :versions (bench-package-versions))
                (when vc (list :revision (bench-vc-revision (car vc))))
                bench-result))
         (json-encoding-pretty-print nil))
    (with-temp-buffer
      (insert (json-encode (bench--json-ready line)) "\n")
      (append-to-file (point-min) (point-max)
                      (expand-file-name "results/raw.jsonl" bench-root)))
    (message "RESULT %s" (json-encode (bench--json-ready bench-result)))))

(defun bench--json-ready (plist)
  "Turn PLIST into something `json-encode' writes as an object."
  (let (alist)
    (while plist
      (let ((key (substring (symbol-name (pop plist)) 1))
            (value (pop plist)))
        (push (cons key (cond ((and (consp value) (consp (car value))
                                    (symbolp (caar value)))
                               (mapcar (lambda (c) (cons (symbol-name (car c)) (cdr c)))
                                       value))
                              ((and (consp value) (keywordp (car value)))
                               (bench--json-ready value))
                              (t value)))
              alist)))
    (nreverse alist)))

(defun bench-ms (seconds) (and seconds (/ (round (* seconds 10000)) 10.0)))

;;; Operations

(defun bench-lookup-hub ()
  (bench-tool-lookup (plist-get bench-corpus-info :hub-id)))

(defun bench-op-cold ()
  "Build the index from nothing."
  (let ((run (bench-time (bench-tool-cold-index))))
    (bench-put :ms (bench-ms (car run))))
  (bench-put :indexed (bench-tool-count))
  (let ((persist (bench-time (bench-tool-persist))))
    (bench-put :persist-ms (bench-ms (car persist))))
  (unless (bench-lookup-hub)
    (error "Hub note not found after cold index")))

(defun bench-expected-notes ()
  "Number of notes in the corpus: one per :ID: line."
  (string-to-number
   (shell-command-to-string
    (format "grep -rh '^:ID:' %s | wc -l"
            (shell-quote-argument (expand-file-name "notes" bench-corpus))))))

(defun bench-op-first-run ()
  "Start on an empty index as a user's init would, until all is indexed.

Reports the time until every note is indexed and the longest freeze
on the way, which is what tells a background index from a blocking
one."
  (let* ((expected (bench-expected-notes))
         (last-check 0.0)
         (count 0)
         (indexed-p (lambda ()
                      ;; Counting can be expensive at 100k; look twice a second
                      (when (> (- (bench-now) last-check) 0.5)
                        (setq last-check (bench-now)
                              count (or (ignore-errors (bench-tool-count)) 0)))
                      (>= count expected)))
         (start (bench-time (bench-tool-start)))
         (wait (bench-idle-until indexed-p 7200)))
    (bench-put :start-ms (bench-ms (car start)))
    (bench-put :ms (bench-ms (+ (car start) (plist-get wait :wall))))
    (bench-put :max-block-ms (bench-ms (max (car start) (plist-get wait :max-block))))
    (bench-put :total-block-ms (bench-ms (+ (car start) (plist-get wait :total-block))))
    (bench-put :indexed count)
    (bench-put :done (plist-get wait :done))))

(defun bench-op-warm ()
  "Start as a user's init would, until a known note can be looked up."
  (let* ((start (bench-time (bench-tool-start)))
         (wait (bench-idle-until #'bench-lookup-hub 600)))
    (bench-put :start-ms (bench-ms (car start)))
    (bench-put :ms (bench-ms (+ (car start) (plist-get wait :wall))))
    (bench-put :done (plist-get wait :done))
    (bench-put :max-block-ms (bench-ms (plist-get wait :max-block)))))

(defun bench-ready ()
  "Start the tool and let startup work finish, untimed."
  (bench-tool-start)
  (unless (plist-get (bench-idle-until #'bench-lookup-hub 600) :done)
    (error "Tool never became ready"))
  (bench-settle 5))

(defun bench-op-find ()
  "Time the find command up to its minibuffer, then list every candidate."
  (bench-ready)
  (let* ((captured nil)
         (capture (lambda (_prompt collection &rest _)
                    (setq captured collection)
                    (throw 'bench-find nil))))
    (advice-add 'completing-read :override capture)
    (unwind-protect
        (let ((open (bench-time
                      (catch 'bench-find
                        (call-interactively (bench-tool-find-command))))))
          (unless captured (error "Find command never reached completing-read"))
          (let ((list (bench-time (all-completions "" captured))))
            (bench-put :open-ms (bench-ms (car open)))
            (bench-put :list-ms (bench-ms (car list)))
            (bench-put :ms (bench-ms (+ (car open) (car list))))
            (bench-put :candidates (length (cdr list)))))
      (advice-remove 'completing-read capture))))

(defun bench-op-backlinks ()
  "Time fetching the notes that link to the hub; median of 5."
  (bench-ready)
  (let* ((id (plist-get bench-corpus-info :hub-id))
         (runs (cl-loop repeat 5 collect (bench-time (bench-tool-backlinks id))))
         (times (sort (mapcar #'car runs) #'<)))
    ;; The first call pays for any cache the tool fills on demand
    (bench-put :first-ms (bench-ms (caar runs)))
    (bench-put :ms (bench-ms (nth 2 times)))
    (bench-put :sources (cdar runs))))

(defun bench-op-save (file)
  "Add a heading with a new ID to FILE, save, wait until it is findable."
  (bench-ready)
  (let* ((path (expand-file-name (format "big/%s" file) bench-corpus))
         (id (org-id-new))
         (visit (bench-time (find-file-noselect path)))
         (buffer (cdr visit)))
    (bench-put :visit-ms (bench-ms (car visit)))
    (with-current-buffer buffer
      (goto-char (point-max))
      (insert (format "\n* Bench marker %s\n:PROPERTIES:\n:ID:       %s\n:END:\n" id id))
      (let* ((save (bench-time (save-buffer)))
             (wait (bench-idle-until (lambda () (bench-tool-lookup id)) 900)))
        (bench-put :save-ms (bench-ms (car save)))
        (bench-put :max-block-ms (bench-ms (max (car save) (plist-get wait :max-block))))
        (bench-put :total-block-ms (bench-ms (+ (car save) (plist-get wait :total-block))))
        (bench-put :ms (bench-ms (+ (car save) (plist-get wait :wall))))
        (bench-put :done (plist-get wait :done))))
    ;; Leave the corpus as it was for the next run
    (with-current-buffer buffer
      (goto-char (point-max))
      (when (re-search-backward "^\\* Bench marker " nil t)
        (delete-region (1- (point)) (point-max)))
      (let ((inhibit-message t)) (save-buffer)))))

;;; Main

(defun bench-main (tool corpus op)
  (setq bench-tool tool
        bench-corpus (file-name-as-directory corpus)
        bench-corpus-info (with-temp-buffer
                            (insert-file-contents (expand-file-name "corpus.eld" corpus))
                            (read (current-buffer)))
        bench-state (expand-file-name
                     (format "data/state/%s/%s/" tool
                             (file-name-nondirectory (directory-file-name corpus)))
                     bench-root))
  (when (memq op '(cold first-run))
    (delete-directory bench-state t))
  (make-directory bench-state t)
  (setq user-emacs-directory (expand-file-name "emacs.d/" bench-state)
        package-user-dir (expand-file-name (format ".deps/%s" tool) bench-root)
        org-id-locations-file (expand-file-name "org-id-locations" bench-state)
        large-file-warning-threshold nil
        make-backup-files nil
        auto-save-default nil
        create-lockfiles nil)
  (make-directory user-emacs-directory t)
  ;; Editor features with idle timers would run in the visited buffer
  ;; during the save benchmarks and count against whichever tool is
  ;; measured (show-paren scanning a 10MB buffer takes ~250ms)
  (show-paren-mode -1)
  (global-eldoc-mode -1)
  (package-initialize)
  (require 'org)
  (require 'org-id)
  (load (expand-file-name (format "adapters/%s.el" (plist-get (alist-get tool bench-tools) :adapter))
                          bench-root)
        nil t)
  (bench-tool-configure bench-corpus bench-state)
  (bench-put :op (symbol-name op))
  (pcase op
    ('cold (bench-op-cold))
    ('first-run (bench-op-first-run))
    ('warm (bench-op-warm))
    ('find (bench-op-find))
    ('backlinks (bench-op-backlinks))
    ('save-1mb (bench-op-save "big-1mb.org"))
    ('save-10mb (bench-op-save "big-10mb.org"))
    (_ (error "Unknown op %s" op)))
  (bench-write-result))

(when (and noninteractive command-line-args-left)
  (let ((tool (intern (pop command-line-args-left)))
        (corpus (expand-file-name (pop command-line-args-left)))
        (op (intern (pop command-line-args-left))))
    (setq command-line-args-left nil)
    (bench-main tool corpus op)))

(provide 'bench)
;;; bench.el ends here
