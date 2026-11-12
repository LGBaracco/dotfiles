;;; lisp/+jupyter-cells.el -*- lexical-binding: t; -*-
;;
;; Notebook buffers: `# %%' cells (code-cells.el) evaluated in the buffer's kernel
;; (+jupyter-kernels) with molten-like output under each cell: a bordered block
;; whose colour tracks the cell state, text (ANSI colours kept), plots inline,
;; long output truncated with a footer.
;;
;; .ipynb files open as percent text via bin/nbsync.py; the saved outputs render
;; under their cells and :w writes the notebook back with exactly the outputs
;; shown (cell ids and notebook metadata kept). code-cells' own ipynb conversion
;; would drop all outputs, so it is replaced.

(require 'cl-lib)
(require 'subr-x)
(require 'ansi-color)
(require '+jupyter-kernels)

(defcustom +notebook-python
  (let ((tool (expand-file-name "~/.local/share/uv/tools/jupytext/bin/python")))
    (if (file-executable-p tool)
        (list tool "-I")
      (list "uv" "run" "--quiet" "--no-project" "--with" "jupytext" "python" "-I")))
  "Command prefix running bin/nbsync.py (needs jupytext + nbformat)."
  :type '(repeat string))

(defcustom +notebook-output-max-lines 64
  "Lines of output text shown under a cell before truncation (`,o' shows all)."
  :type 'integer)

(defcustom +notebook-image-max-lines 25
  "Maximum height of inline plots, in lines."
  :type 'integer)

(defcustom +notebook-auto-attach t
  "Attach a kernel when a local .ipynb is opened (project kernel, else its kernelspec)."
  :type 'boolean)

(defface +notebook-output '((t :foreground "#dde1e6")) "Cell output text.")
(defface +notebook-border '((t :foreground "#665c54")) "Output border (pending).")
(defface +notebook-border-running '((t :foreground "#83a598")) "Output border (running).")
(defface +notebook-border-ok '((t :foreground "#b8bb26")) "Output border (success).")
(defface +notebook-border-error '((t :foreground "#fb4934")) "Output border (error).")
(defface +notebook-footer '((t :foreground "#83a598" :slant italic)) "Truncation footer.")

(defconst +notebook--nbsync
  (expand-file-name "../bin/nbsync.py" (file-name-directory (or load-file-name buffer-file-name))))

(defconst +notebook--non-code-re "\\[\\(?:markdown\\|md\\|raw\\)\\]"
  "Cell header suffix of non-code cells (jupytext percent format).")

(defvar-local +notebook--hidden nil "Non-nil hides inline outputs (`,v').")
(defvar-local +notebook--ipynb-raw nil "Last read/written .ipynb JSON of this buffer.")
(defvar-local +notebook--language "python" "Notebook language (from the .ipynb).")
(put '+notebook--ipynb-raw 'permanent-local t)
(put '+notebook--language 'permanent-local t)

;;; Cells

(defun +notebook--cells ()
  "Cells of the buffer as plists (:beg :body :end :code), in order.
:beg is the header line start (point-min for a headerless preamble), :body the
first body position, :end the end of the last non-blank body line."
  (save-excursion
    (goto-char (point-min))
    (let (heads cells)
      (while (re-search-forward code-cells-boundary-regexp nil t)
        (push (match-beginning 0) heads)
        (goto-char (line-end-position)))
      (setq heads (nreverse heads))
      (when (or (null heads) (> (car heads) (point-min)))
        (let ((stop (or (car heads) (point-max))))
          (when (string-match-p "[^ \t\n]" (buffer-substring-no-properties (point-min) stop))
            (push (list :beg (point-min) :body (point-min) :limit stop :code t) cells))))
      (cl-loop for (h next) on heads
               do (goto-char h)
               (push (list :beg h
                           :body (min (1+ (line-end-position)) (point-max))
                           :limit (or next (point-max))
                           :code (not (string-match-p +notebook--non-code-re
                                                      (buffer-substring-no-properties h (line-end-position)))))
                     cells))
      (mapcar (lambda (c)
                (goto-char (plist-get c :limit))
                (skip-chars-backward " \t\n" (plist-get c :body))
                (plist-put c :end (max (if (> (point) (plist-get c :body)) (line-end-position) (point))
                                       (save-excursion (goto-char (plist-get c :beg)) (line-end-position)))))
              (nreverse cells)))))

(defun +notebook--cell-at (&optional pos)
  (let ((pos (or pos (point))))
    (cl-find-if (lambda (c) (and (>= pos (plist-get c :beg)) (< pos (plist-get c :limit))))
                (+notebook--cells) :from-end t)))

(defun +notebook--cell-code (cell)
  (string-trim-right (buffer-substring-no-properties (plist-get cell :body)
                                                     (max (plist-get cell :body) (plist-get cell :end)))))

;;; Output overlays

(defun +notebook--overlays (&optional beg end region)
  "Output overlays starting in BEG..END; cell overlays, or REGION ones if non-nil."
  (cl-remove-if-not
   (lambda (ov) (and (overlay-get ov '+notebook)
                     (eq (and (overlay-get ov '+notebook-region) t) (and region t))
                     (>= (overlay-start ov) (or beg (point-min)))
                     (< (overlay-start ov) (or end (1+ (point-max))))))
   (overlays-in (or beg (point-min)) (or end (point-max)))))

(defun +notebook--cell-overlay (cell)
  (car (+notebook--overlays (plist-get cell :beg) (plist-get cell :limit))))

(defun +notebook--make-overlay (beg end &optional region)
  (let ((ov (make-overlay beg end nil nil t)))
    (overlay-put ov '+notebook t)
    (overlay-put ov '+notebook-region region)
    (overlay-put ov 'evaporate nil)
    (overlay-put ov '+notebook-outputs nil)
    ov))

(defun +notebook--delete-overlay (ov)
  (when-let* ((timer (overlay-get ov '+notebook-timer))) (cancel-timer timer))
  (delete-overlay ov))

;;; Rendering

(defun +notebook--ansi (s)
  "S with ANSI colours applied as `face' (overlay strings ignore `font-lock-face')."
  (let ((s (ansi-color-apply (or s ""))) (pos 0))
    (while (< pos (length s))
      (let ((next (or (next-single-property-change pos 'font-lock-face s) (length s)))
            (face (get-text-property pos 'font-lock-face s)))
        (when face (add-face-text-property pos next face nil s))
        (setq pos next)))
    s))

(defun +notebook--plain (x)
  (cond ((stringp x) x)
        ((vectorp x) (mapconcat #'identity x ""))
        (t "")))

(defun +notebook--output-text (out)
  "Plain text of nbformat output OUT (no images); non-stream text ends in a newline."
  (let ((s (+notebook--output-text-1 out)))
    (if (or (string-empty-p s) (equal (plist-get out :output_type) "stream")
            (string-suffix-p "\n" s))
        s
      (concat s "\n"))))

(defun +notebook--output-text-1 (out)
  (pcase (plist-get out :output_type)
    ("stream" (+notebook--plain (plist-get out :text)))
    ("error" (let ((tb (plist-get out :traceback)))
               (if (and tb (> (length tb) 0))
                   (mapconcat #'identity tb "\n")
                 (format "%s: %s" (plist-get out :ename) (plist-get out :evalue)))))
    ((or "execute_result" "display_data")
     (let ((data (plist-get out :data)))
       (+notebook--plain (or (plist-get data :text/plain)
                             (plist-get data :text/markdown)
                             (plist-get data :text/latex)
                             (and (plist-get data :text/html) "[HTML output: ,b opens it]")))))
    (_ "")))

(defun +notebook--image-spec (out)
  "(TYPE . DATA) of the first image in OUT, or nil."
  (when (member (plist-get out :output_type) '("execute_result" "display_data"))
    (let ((data (plist-get out :data)))
      (cl-loop for (mime . type) in '((:image/png . png) (:image/jpeg . jpeg) (:image/svg+xml . svg))
               for d = (plist-get data mime)
               when d return (cons type (+notebook--plain d))))))

(defun +notebook--image (spec &optional full)
  "Emacs image for SPEC; scaled to the window unless FULL."
  (when (and spec (display-images-p))
    (ignore-errors
      (let* ((type (car spec))
             (bytes (if (eq type 'svg) (cdr spec)
                      (base64-decode-string (replace-regexp-in-string "[ \t\n\r]" "" (cdr spec)))))
             (win (or (get-buffer-window (current-buffer)) (selected-window)))
             (width (max 200 (- (window-body-width win t) (* 4 (frame-char-width))))))
        (apply #'create-image bytes type t :ascent 'center
               (if full (list :max-width width)
                 (list :max-width width
                       :max-height (* +notebook-image-max-lines (default-line-height)))))))))

(defun +notebook--border-face (status)
  (pcase status
    ('ok '+notebook-border-ok)
    ('error '+notebook-border-error)
    ('running '+notebook-border-running)
    (_ '+notebook-border)))

(defun +notebook--header (ov)
  (let* ((status (overlay-get ov '+notebook-status))
         (count (overlay-get ov '+notebook-count))
         (elapsed (overlay-get ov '+notebook-elapsed))
         (start (overlay-get ov '+notebook-start)))
    (format "╭─ [%s] %s%s"
            (if (integerp count) count (if (memq status '(running pending)) "*" " "))
            (pcase status ('ok "✔") ('error "✘") ('running "…") ('pending "⋯") ('aborted "■") (_ ""))
            (cond (elapsed (format " %.2fs" elapsed))
                  ((and start (eq status 'running)) (format " %.1fs" (- (float-time) start)))
                  (t "")))))

(defun +notebook--render-string (ov &optional full)
  "Display string of OV's outputs; truncated unless FULL."
  (let* ((face (+notebook--border-face (overlay-get ov '+notebook-status)))
         (bar (propertize "│ " 'face face))
         (pieces nil) (text ""))
    ;; Merge consecutive text, keep images as separate pieces.
    (dolist (out (overlay-get ov '+notebook-outputs))
      (let ((img (+notebook--image-spec out)))
        (if (and img (display-images-p))
            (progn (unless (string-empty-p text) (push (cons 'text text) pieces) (setq text ""))
                   (push (cons 'image img) pieces))
          (setq text (concat text (+notebook--output-text out))))))
    (unless (string-empty-p text) (push (cons 'text text) pieces))
    (setq pieces (nreverse pieces))
    (let* ((lines-total 0)
           (body
            (mapcan
             (lambda (p)
               (if (eq (car p) 'image)
                   (when-let* ((img (+notebook--image (cdr p) full)))
                     (list (concat bar (propertize " " 'display img))))
                 (let ((lines (split-string (string-trim-right (+notebook--ansi (cdr p)) "\n+") "\n")))
                   (setq lines-total (+ lines-total (length lines)))
                   (mapcar (lambda (l)
                             (let ((l (copy-sequence l)))
                               (add-face-text-property 0 (length l) '+notebook-output t l)
                               (concat bar l)))
                           lines))))
             pieces))
           (dropped 0))
      (when (and (not full) (> lines-total +notebook-output-max-lines))
        ;; Keep the tail (latest output); images always stay.
        (let ((excess (- lines-total +notebook-output-max-lines)) kept)
          (dolist (l body)
            (if (and (> excess 0) (not (get-text-property 2 'display l)))
                (progn (cl-decf excess) (cl-incf dropped))
              (push l kept)))
          (setq body (nreverse kept))))
      (string-join
       (append (list (propertize (+notebook--header ov) 'face face))
               (when (> dropped 0)
                 (list (concat bar (propertize (format "… %d earlier lines (,o shows all)" dropped)
                                               'face '+notebook-footer))))
               body
               (list (propertize "╰─" 'face face)))
       "\n"))))

(defun +notebook--render (ov)
  (when (overlay-buffer ov)
    (with-current-buffer (overlay-buffer ov)
      (overlay-put ov '+notebook-timer nil)
      (if +notebook--hidden
          (overlay-put ov 'after-string nil)
        (let ((s (concat "\n" (+notebook--render-string ov))))
          ;; Cursor at the cell's last line stays there, not after the output block.
          (put-text-property 0 1 'cursor t s)
          (overlay-put ov 'after-string s))))))

(defun +notebook--schedule-render (ov)
  (unless (overlay-get ov '+notebook-timer)
    (overlay-put ov '+notebook-timer (run-with-timer 0.2 nil #'+notebook--render ov))))

;;; Executing

(defun +notebook--add-output (ov out)
  "Append nbformat output OUT to OV (consecutive streams of one name merge)."
  (let* ((outs (overlay-get ov '+notebook-outputs))
         (last (car (last outs))))
    (if (and last (equal (plist-get out :output_type) "stream")
             (equal (plist-get last :output_type) "stream")
             (equal (plist-get last :name) (plist-get out :name)))
        (plist-put last :text (concat (+notebook--plain (plist-get last :text)) (plist-get out :text)))
      (overlay-put ov '+notebook-outputs (append outs (list out))))))

(defun +notebook--callbacks (ov token)
  "Message callbacks filling OV; ignored once OV runs a newer request than TOKEN."
  (let ((buf (current-buffer)) (clear-on-next nil))
    (cl-labels ((live () (and (overlay-buffer ov) (eq (overlay-get ov '+notebook-token) token)))
                (add (out)
                  (when clear-on-next (overlay-put ov '+notebook-outputs nil) (setq clear-on-next nil))
                  (+notebook--add-output ov out)
                  (+notebook--schedule-render ov))
                (on (fn) (lambda (msg) (when (live) (funcall fn (jupyter-message-content msg))))))
      `(("execute_input"
         ,(on (lambda (c)
                (overlay-put ov '+notebook-count (plist-get c :execution_count))
                (overlay-put ov '+notebook-status 'running)
                (overlay-put ov '+notebook-start (float-time))
                (+notebook--schedule-render ov)
                (when (buffer-live-p buf) (with-current-buffer buf (force-mode-line-update))))))
        ("stream"
         ,(on (lambda (c)
                (add (list :output_type "stream" :name (plist-get c :name) :text (plist-get c :text))))))
        ("execute_result"
         ,(on (lambda (c)
                (add (list :output_type "execute_result" :data (plist-get c :data)
                           :metadata (plist-get c :metadata)
                           :execution_count (or (plist-get c :execution_count) :null))))))
        ("display_data"
         ,(on (lambda (c)
                (add (list :output_type "display_data" :data (plist-get c :data)
                           :metadata (plist-get c :metadata))))))
        ("clear_output"
         ,(on (lambda (c)
                (if (eq (plist-get c :wait) t)
                    (setq clear-on-next t)
                  (overlay-put ov '+notebook-outputs nil)
                  (+notebook--schedule-render ov)))))
        ("error"
         ,(on (lambda (c)
                (add (list :output_type "error" :ename (plist-get c :ename)
                           :evalue (plist-get c :evalue)
                           :traceback (vconcat (plist-get c :traceback)))))))
        ("execute_reply"
         ,(on (lambda (c)
                (let ((status (plist-get c :status))
                      (count (plist-get c :execution_count)))
                  (overlay-put ov '+notebook-status
                               (pcase status ("ok" 'ok) ("aborted" 'aborted) (_ 'error)))
                  (when (integerp count) (overlay-put ov '+notebook-count count))
                  (dolist (o (overlay-get ov '+notebook-outputs))
                    (when (equal (plist-get o :output_type) "execute_result")
                      (plist-put o :execution_count (or (overlay-get ov '+notebook-count) :null))))
                  (when-let* ((start (overlay-get ov '+notebook-start)))
                    (overlay-put ov '+notebook-elapsed (- (float-time) start))))
                (when-let* ((timer (overlay-get ov '+notebook-timer))) (cancel-timer timer))
                (+notebook--render ov)
                (when (buffer-live-p buf)
                  (with-current-buffer buf (force-mode-line-update))))))))))

(defun +notebook--execute (code ov)
  "Run CODE in the buffer's kernel; outputs go to OV (cleared first)."
  (unless (+jupyter-client-live-p)
    (user-error "No kernel attached (,i project / ,I server / ,k pick)"))
  (let ((token (list 'run)))
    (overlay-put ov '+notebook-token token)
    (overlay-put ov '+notebook-outputs nil)
    (overlay-put ov '+notebook-count nil)
    (overlay-put ov '+notebook-elapsed nil)
    (overlay-put ov '+notebook-start (float-time))
    (overlay-put ov '+notebook-status 'pending)
    (+notebook--render ov)
    (+jupyter-execute code :callbacks (+notebook--callbacks ov token) :store-history t)))

(defun +notebook--run-cell (cell)
  (if (not (plist-get cell :code))
      (message "jupyter: not a code cell")
    (let ((code (+notebook--cell-code cell)))
      (if (string-empty-p code)
          (message "jupyter: empty cell")
        (let ((ov (or (+notebook--cell-overlay cell)
                      (+notebook--make-overlay (plist-get cell :beg) (plist-get cell :end)))))
          (move-overlay ov (plist-get cell :beg) (plist-get cell :end))
          (+notebook--execute code ov))))))

(defun +notebook--run-region (beg end)
  "Run BEG..END (whole lines); its output sits under the last line."
  (let* ((beg (save-excursion (goto-char beg) (line-beginning-position)))
         (end (save-excursion (goto-char end)
                              (when (and (bolp) (> end beg)) (backward-char))
                              (line-end-position)))
         (code (buffer-substring-no-properties beg end)))
    (when (string-blank-p code) (user-error "Nothing to run"))
    (dolist (ov (+notebook--overlays beg (1+ end) t))
      (when (= (overlay-end ov) end) (+notebook--delete-overlay ov)))
    (+notebook--execute (string-trim-right code) (+notebook--make-overlay beg end t))))

;;; Commands

(defun +notebook/run-cell ()
  "Run the cell at point."
  (interactive)
  (+notebook--run-cell (or (+notebook--cell-at) (user-error "No cell here"))))

(defun +notebook/run-line ()
  (interactive)
  (+notebook--run-region (line-beginning-position) (line-end-position)))

(after! evil
  (evil-define-operator +notebook:eval (beg end)
    "Run the text covered by a motion / the visual selection."
    :move-point nil
    (+notebook--run-region beg end)))

(defun +notebook--run-cells (pred)
  (let ((n 0))
    (dolist (cell (+notebook--cells))
      (when (and (plist-get cell :code) (funcall pred cell)
                 (not (string-empty-p (+notebook--cell-code cell))))
        (+notebook--run-cell cell)
        (cl-incf n)))
    (message "jupyter: queued %d cell%s" n (if (= n 1) "" "s"))))

(defun +notebook/run-above ()
  "Run all code cells up to and including the current one."
  (interactive)
  (let ((here (plist-get (+notebook--cell-at) :beg)))
    (+notebook--run-cells (lambda (c) (<= (plist-get c :beg) (or here (point)))))))

(defun +notebook/run-all ()
  (interactive)
  (+notebook--run-cells #'always))

(defun +notebook/rerun-all ()
  "Re-run every cell that currently has an output."
  (interactive)
  (+notebook--run-cells #'+notebook--cell-overlay))

(defun +notebook/delete-output ()
  "Delete the current cell's output (and region outputs inside it)."
  (interactive)
  (when-let* ((cell (+notebook--cell-at)))
    (dolist (ov (append (+notebook--overlays (plist-get cell :beg) (plist-get cell :limit))
                        (+notebook--overlays (plist-get cell :beg) (plist-get cell :limit) t)))
      (+notebook--delete-overlay ov))))

(defun +notebook/delete-all-outputs ()
  (interactive)
  (dolist (ov (append (+notebook--overlays) (+notebook--overlays nil nil t)))
    (+notebook--delete-overlay ov)))

(defun +notebook/toggle-outputs ()
  (interactive)
  (setq +notebook--hidden (not +notebook--hidden))
  (mapc #'+notebook--render (append (+notebook--overlays) (+notebook--overlays nil nil t)))
  (message "jupyter: outputs %s" (if +notebook--hidden "hidden" "shown")))

(defun +notebook--output-overlay-at ()
  "Output overlay of a region output ending on this line, else of the current cell."
  (or (cl-find-if (lambda (ov) (= (overlay-end ov) (line-end-position)))
                  (+notebook--overlays (point-min) (1+ (line-end-position)) t))
      (when-let* ((cell (+notebook--cell-at))) (+notebook--cell-overlay cell))
      (user-error "No output here")))

(defun +notebook/show-output ()
  "Full output of the cell at point in a focused popup (yank / inspect)."
  (interactive)
  (let* ((ov (+notebook--output-overlay-at))
         (s (with-current-buffer (overlay-buffer ov) (+notebook--render-string ov t)))
         (buf (get-buffer-create "*jupyter-cell-output*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert s)
        (goto-char (point-min)))
      (special-mode))
    (pop-to-buffer buf)))

(defun +notebook--output-plain (ov)
  (substring-no-properties
   (ansi-color-filter-apply
    (mapconcat #'+notebook--output-text (overlay-get ov '+notebook-outputs) ""))))

(defun +notebook/yank-output ()
  "Copy the output text to the kill ring (not the clipboard)."
  (interactive)
  (let ((select-enable-clipboard nil))
    (kill-new (+notebook--output-plain (+notebook--output-overlay-at))))
  (message "jupyter: output yanked"))

(defun +notebook/yank-output-clipboard ()
  (interactive)
  (let ((s (+notebook--output-plain (+notebook--output-overlay-at))))
    (kill-new s)
    (gui-set-selection 'CLIPBOARD s))
  (message "jupyter: output copied to the clipboard"))

(defun +notebook--first-output-with (pred)
  (cl-find-if pred (overlay-get (+notebook--output-overlay-at) '+notebook-outputs)))

(defun +notebook/image-popup ()
  "Open the cell's first image in the system viewer."
  (interactive)
  (let* ((spec (cl-some #'+notebook--image-spec
                        (overlay-get (+notebook--output-overlay-at) '+notebook-outputs)))
         (file (make-temp-file "jupyter-" nil (format ".%s" (if spec (car spec) "png")))))
    (unless spec (user-error "No image output here"))
    (let ((coding-system-for-write 'binary))
      (with-temp-file file
        (set-buffer-multibyte nil)
        (insert (if (eq (car spec) 'svg) (encode-coding-string (cdr spec) 'utf-8)
                  (base64-decode-string (replace-regexp-in-string "[ \t\n\r]" "" (cdr spec)))))))
    (call-process "xdg-open" nil 0 nil file)))

(defun +notebook/open-html ()
  "Open the cell's HTML output in the browser."
  (interactive)
  (let* ((out (+notebook--first-output-with
               (lambda (o) (plist-get (plist-get o :data) :text/html))))
         (file (make-temp-file "jupyter-" nil ".html")))
    (unless out (user-error "No HTML output here"))
    (with-temp-file file
      (insert (+notebook--plain (plist-get (plist-get out :data) :text/html))))
    (browse-url-of-file file)))

(defun +notebook/restart-clear ()
  "Restart the kernel and clear all outputs."
  (interactive)
  (+jupyter/restart)
  (+notebook/delete-all-outputs))

(defun +notebook/quit ()
  "Shut the kernel down and clear all outputs."
  (interactive)
  (+jupyter/shutdown)
  (+notebook/delete-all-outputs))

;;; Navigation and text objects

(defun +notebook--body-starts ()
  (mapcar (lambda (c) (plist-get c :body)) (+notebook--cells)))

(defun +notebook/next-cell (&optional n)
  "Move to the body of the Nth next cell."
  (interactive "p")
  (let ((targets (cl-remove-if-not (lambda (p) (> p (point))) (+notebook--body-starts))))
    (goto-char (or (nth (1- (max 1 (or n 1))) targets) (car (last targets)) (point)))))

(defun +notebook/prev-cell (&optional n)
  "Move to the body of the Nth previous cell."
  (interactive "p")
  (let ((targets (reverse (cl-remove-if-not (lambda (p) (< p (point))) (+notebook--body-starts)))))
    (goto-char (or (nth (1- (max 1 (or n 1))) targets) (car (last targets)) (point)))))

(defun +notebook/goto-cell (n)
  "Move to cell N (prefix count, 1-based)."
  (interactive "p")
  (goto-char (or (nth (1- (max 1 n)) (+notebook--body-starts)) (user-error "No cell %d" n))))

(after! evil
  (evil-define-text-object +notebook-inner-cell (count &optional _beg _end _type)
    "Cell body without header and trailing blank lines."
    (let ((c (or (+notebook--cell-at) (user-error "No cell here"))))
      (evil-range (plist-get c :body)
                  (min (point-max) (1+ (max (plist-get c :body) (plist-get c :end))))
                  'line)))

  (evil-define-text-object +notebook-outer-cell (count &optional _beg _end _type)
    "Whole cell: header, body and trailing blank lines."
    (let ((c (or (+notebook--cell-at) (user-error "No cell here"))))
      (evil-range (plist-get c :beg) (plist-get c :limit) 'line)))

  ;; Only in notebook buffers (`map! :textobj' would rebind ib/ab globally);
  ;; the `i'/`a' prefixes merge with evil's text-object maps, so `iw' etc. still work.
  (evil-define-key '(visual operator) +notebook-mode-map
    "ib" #'+notebook-inner-cell
    "ab" #'+notebook-outer-cell))

;;; .ipynb files

(defun +notebook--nbsync (op input)
  "Run nbsync.py OP with INPUT (string) on stdin; return stdout or signal."
  (let ((default-directory temporary-file-directory)
        (err (make-temp-file "nbsync-err")))
    (unwind-protect
        (with-temp-buffer
          (insert input)
          (let* ((coding-system-for-read 'utf-8-unix)
                 (coding-system-for-write 'utf-8-unix)
                 (status (apply #'call-process-region (point-min) (point-max)
                                (car +notebook-python) t (list t err) nil
                                (append (cdr +notebook-python) (list +notebook--nbsync op)))))
            (unless (eq status 0)
              (error "nbsync %s failed (%s): %s" op status
                     (with-temp-buffer (insert-file-contents err) (string-trim (buffer-string)))))
            (buffer-string)))
      (delete-file err))))

(defconst +notebook--new-template
  "{\n \"cells\": [\n  {\"cell_type\": \"markdown\", \"metadata\": {}, \"source\": [\"# %s\"]},\n  {\"cell_type\": \"code\", \"execution_count\": null, \"metadata\": {}, \"outputs\": [], \"source\": []}\n ],\n \"metadata\": {\n  \"kernelspec\": {\"display_name\": \"Python 3\", \"language\": \"python\", \"name\": \"python3\"},\n  \"language_info\": {\"name\": \"python\"}\n },\n \"nbformat\": 4,\n \"nbformat_minor\": 5\n}\n")

(defun +notebook--language-mode (lang)
  (let ((mode (pcase (downcase (or lang "python"))
                ("python" 'python-mode) ("julia" 'julia-mode)
                ("r" 'ess-r-mode) ("bash" 'sh-mode) (_ 'python-mode))))
    (if (fboundp 'major-mode-remap) (major-mode-remap mode) mode)))

(defun +notebook--load (raw)
  "Replace the buffer with RAW notebook JSON as percent text + rendered outputs."
  (let* ((raw (if (string-blank-p raw)
                  (format +notebook--new-template
                          (file-name-base (or buffer-file-name "notebook")))
                raw))
         (res (json-parse-string (+notebook--nbsync "read" raw)
                                 :object-type 'plist :array-type 'array
                                 :null-object :null :false-object :false))
         (inhibit-read-only t))
    (setq +notebook--ipynb-raw raw
          +notebook--language (plist-get res :language))
    (+notebook/delete-all-outputs)
    (erase-buffer)
    (insert (plist-get res :text))
    (goto-char (point-min))
    (let ((cells (cl-remove-if-not (lambda (c) (plist-get c :code)) (+notebook--cells))))
      (cl-loop for cell in cells
               for saved across (plist-get res :cells)
               for outs = (append (plist-get saved :outputs) nil)
               when outs
               do (let ((ov (+notebook--make-overlay (plist-get cell :beg) (plist-get cell :end)))
                        (count (plist-get saved :execution_count)))
                    (overlay-put ov '+notebook-outputs outs)
                    (overlay-put ov '+notebook-count (and (integerp count) count))
                    (overlay-put ov '+notebook-status
                                 (if (cl-some (lambda (o) (equal (plist-get o :output_type) "error")) outs)
                                     'error 'ok))
                    (+notebook--render ov))))))

(defun +notebook--outputs-for-save ()
  "Vector with one entry per code cell: (:execution_count N :outputs [..]) or :null."
  (vconcat
   (mapcar (lambda (cell)
             (if-let* ((ov (+notebook--cell-overlay cell)))
                 (list :execution_count (or (overlay-get ov '+notebook-count) :null)
                       :outputs (vconcat (overlay-get ov '+notebook-outputs)))
               :null))
           (cl-remove-if-not (lambda (c) (plist-get c :code)) (+notebook--cells)))))

(defun +notebook--ipynb-json (&optional old)
  "Notebook JSON for the buffer, metadata from OLD (default: the file as read)."
  (+notebook--nbsync
   "write"
   (json-serialize
    (list :text (buffer-substring-no-properties (point-min) (point-max))
          :language (or +notebook--language "python")
          :old (or old +notebook--ipynb-raw :null)
          :cells (+notebook--outputs-for-save)))))

(defun +notebook--write-ipynb ()
  "`write-contents-functions' handler: write the buffer back as .ipynb."
  (let ((json (+notebook--ipynb-json))
        (file buffer-file-name))
    (with-temp-buffer
      (insert json)
      (let ((coding-system-for-write 'utf-8-unix))
        (write-region (point-min) (point-max) file nil 'silent)))
    (setq +notebook--ipynb-raw json)
    (set-visited-file-modtime)
    (set-buffer-modified-p nil)
    t))

(defun +notebook--revert (&optional _ignore-auto noconfirm)
  "Re-read the .ipynb (kernel and modes stay)."
  (when (or noconfirm (not (buffer-modified-p))
            (yes-or-no-p "Discard edits and reread the notebook? "))
    (+notebook--reread)))

(defun +notebook--reread ()
  (let ((pt (point)))
    (+notebook--load (let ((file buffer-file-name))
                       (with-temp-buffer (insert-file-contents file) (buffer-string))))
    (set-buffer-modified-p nil)
    (set-visited-file-modtime)
    (goto-char (min pt (point-max)))))

;;;###autoload
(defun +notebook-ipynb-mode ()
  "Open the .ipynb in this buffer as `# %%' text with its saved outputs."
  (let ((raw (buffer-substring-no-properties (point-min) (point-max)))
        (pt (point)))
    (funcall (+notebook--language-mode
              (ignore-errors
                (let ((md (plist-get (json-parse-string raw :object-type 'plist) :metadata)))
                  (or (plist-get (plist-get md :kernelspec) :language)
                      (plist-get (plist-get md :language_info) :name))))))
    (+notebook-mode 1)
    (+notebook--load raw)
    (goto-char (min pt (point-max)))
    (setq buffer-undo-list nil)
    (set-buffer-modified-p nil)
    (add-hook 'write-contents-functions #'+notebook--write-ipynb nil t)
    (setq-local revert-buffer-function #'+notebook--revert)
    (when +notebook-auto-attach
      (run-with-idle-timer 0.3 nil #'+notebook--auto-attach (current-buffer)))))

(defun +notebook--auto-attach (buf)
  "Attach a kernel to notebook BUF: project kernel (uv), else its kernelspec."
  (when (and (buffer-live-p buf) (not (+jupyter-client buf)))
    (with-current-buffer buf
      (condition-case err
          (cond
           ((file-remote-p default-directory)
            (message "jupyter: remote notebook, ,i starts/attaches a server kernel"))
           ((+jupyter-on-fuse-p default-directory)
            (message "jupyter: notebook on an sshfs mount, no local kernel. Open it over TRAMP (/ssh:…) and use ,i"))
           ((cdr (+jupyter-project-root))
            (+jupyter/init))
           (t
            (let ((spec (ignore-errors
                          (plist-get (plist-get (plist-get (json-parse-string +notebook--ipynb-raw :object-type 'plist)
                                                           :metadata)
                                                :kernelspec)
                                     :name))))
              (if (and spec (cl-find spec (+jupyter-local-kernelspecs) :key #'jupyter-kernelspec-name :test #'equal))
                  (+jupyter-attach (+jupyter-start-local-kernel spec default-directory) :name spec)
                (message "jupyter: kernel %s is not installed and this is not a uv project; ,k picks one"
                         (or spec "?"))))))
        (error (message "jupyter: auto-attach failed: %s" (error-message-string err)))))))

(defun +notebook/export-ipynb ()
  "Write the cells (with outputs) to a sibling .ipynb (jupytext-compatible)."
  (interactive)
  (unless buffer-file-name (user-error "Save the buffer first"))
  (when (string-suffix-p ".ipynb" buffer-file-name)
    (user-error "Already a notebook: saving writes the .ipynb"))
  (let* ((target (concat (file-name-sans-extension buffer-file-name) ".ipynb"))
         (old (and (file-exists-p target)
                   (with-temp-buffer (insert-file-contents target) (buffer-string))))
         (json (let ((+notebook--language "python")) (+notebook--ipynb-json (or old :null)))))
    (with-temp-buffer
      (insert json)
      (let ((coding-system-for-write 'utf-8-unix))
        (write-region (point-min) (point-max) target nil 'silent)))
    (message "jupyter: wrote %s" (abbreviate-file-name target))))

(defun +notebook/new (file)
  "Create a blank notebook FILE (.ipynb added) and open it."
  (interactive "FNew notebook: ")
  (let ((file (if (string-suffix-p ".ipynb" file) file (concat file ".ipynb"))))
    (if (file-exists-p file)
        (message "jupyter: %s exists; opening it" (abbreviate-file-name file))
      (make-directory (file-name-directory (expand-file-name file)) t)
      (with-temp-file file
        (insert (format +notebook--new-template (file-name-base file)))))
    (find-file file)))

;;; Markdown cells
;; `# %% [markdown]' bodies are `# '-prefixed comment lines. Restyle them as text
;; with markdown-mode's faces (headings, bold, italic, code, links, lists, quotes,
;; math, ``` fences); the `# ' prefix stays in the buffer, dimmed (hiding it would
;; let `x'/`I' at the line start edit an invisible `#').

(defface +notebook-md-prefix '((t :foreground "#504945")) "`# ' prefix of markdown cell lines.")
(defface +notebook-md-text '((t :inherit default)) "Markdown cell text.")
(defface +notebook-md-h1 '((t :inherit markdown-header-face-1 :height 1.25)) "Markdown heading 1.")
(defface +notebook-md-h2 '((t :inherit markdown-header-face-2 :height 1.1)) "Markdown heading 2.")

(defconst +notebook--md-header-re "\\[\\(?:markdown\\|md\\)\\]"
  "Cell header suffix of markdown cells (raw cells keep the comment look).")

(defconst +notebook--md-inline
  '(("`[^`\n]+`" 0 (0 . markdown-inline-code-face))
    ("\\$[^$\n]+\\$" 0 (0 . markdown-math-face))
    ("\\[\\([^]\n]+\\)\\]\\(([^)\n]+)\\)" 0 (1 . markdown-link-face) (2 . markdown-url-face))
    ("\\*\\*[^*\n]+\\*\\*" 0 (0 . markdown-bold-face))
    ("\\(?:\\=\\|[^*]\\)\\(\\*[^*[:space:]][^*\n]*\\*\\)" 1 (1 . markdown-italic-face)))
  "Inline markdown: (REGEXP SPAN-GROUP (GROUP . FACE)...), earlier rules win overlaps.")

(defun +notebook--cell-header (pos)
  "Start of the `# %%' line of the cell containing POS; nil in the preamble."
  (save-excursion
    (goto-char pos)
    (end-of-line)
    (and (re-search-backward code-cells-boundary-regexp nil t) (point))))

(defun +notebook--cell-limit (pos)
  "Start of the first cell header after POS's line, else `point-max'."
  (save-excursion
    (goto-char pos)
    (end-of-line)
    (if (re-search-forward code-cells-boundary-regexp nil t) (match-beginning 0) (point-max))))

(defun +notebook--md-header-p (header)
  (save-excursion
    (goto-char header)
    (re-search-forward +notebook--md-header-re (line-end-position) t)))

(defun +notebook--md-extend-region ()
  "Grow the font-lock region over whole markdown cells.
A body line's style depends on its header and on ``` fences above it, and
editing a header line restyles the cell below it."
  (let* ((beg font-lock-beg) (end font-lock-end)
         (last (max beg (1- end)))
         (h (+notebook--cell-header beg))
         (h-end (+notebook--cell-header last)))
    (when (and h (+notebook--md-header-p h))
      (setq beg (min beg h)))
    (when (and h-end (or (>= h-end font-lock-beg) (+notebook--md-header-p h-end)))
      (setq end (max end (+notebook--cell-limit last))))
    (prog1 (or (< beg font-lock-beg) (> end font-lock-end))
      (setq font-lock-beg beg font-lock-end end))))

(defun +notebook--md-style-line (bol text eol code)
  "Style one markdown line: `# ' prefix BOL..TEXT, content TEXT..EOL (CODE: in a fence)."
  (put-text-property bol text 'face '+notebook-md-prefix)
  (goto-char text)
  (cond
   (code (put-text-property text eol 'face 'markdown-code-face))
   ((looking-at "\\(#\\{1,6\\}\\)\\(?:[ \t]\\|$\\)")
    (let ((n (- (match-end 1) (match-beginning 1))))
      (put-text-property text eol 'face (pcase n
                                          (1 '+notebook-md-h1)
                                          (2 '+notebook-md-h2)
                                          (_ (intern (format "markdown-header-face-%d" n)))))
      (put-text-property (match-beginning 1) (match-end 1) 'face 'markdown-header-delimiter-face)))
   (t
    (put-text-property text eol 'face (if (looking-at-p "[ \t]*>")
                                          'markdown-blockquote-face
                                        '+notebook-md-text))
    (when (looking-at "[ \t]*\\([-*+]\\|[0-9]+[.)]\\)[ \t]")
      (put-text-property (match-beginning 1) (match-end 1) 'face 'markdown-list-face))
    (let (spans)
      (pcase-dolist (`(,re ,span . ,faces) +notebook--md-inline)
        (goto-char text)
        (while (re-search-forward re eol t)
          (let ((mb (match-beginning span)) (me (match-end span)))
            (unless (cl-some (lambda (s) (and (< mb (cdr s)) (> me (car s)))) spans)
              (push (cons mb me) spans)
              (pcase-dolist (`(,group . ,face) faces)
                (add-face-text-property (match-beginning group) (match-end group) face)))
            (goto-char me))))))))

(defun +notebook--md-fontify (limit)
  "Font-lock matcher: style markdown cell bodies from point to LIMIT.
Applies the faces itself and returns nil."
  (let ((start (point)))
    (save-excursion
      (save-match-data
        (let ((h (or (+notebook--cell-header start) (+notebook--cell-limit start))))
          (while (< h limit)
            (let ((next (+notebook--cell-limit h))
                  (fence nil))
              (when (+notebook--md-header-p h)
                (goto-char h)
                (forward-line 1)
                (while (< (point) next)
                  (let ((bol (point)) (eol (line-end-position)))
                    (when (looking-at "#\\(?: \\|$\\)")
                      (let* ((text (match-end 0))
                             (fence-line (progn (goto-char text)
                                                (looking-at-p "[ \t]*\\(?:```\\|~~~\\)")))
                             (code (or fence fence-line)))
                        (when fence-line (setq fence (not fence)))
                        (when (and (>= bol start) (< bol limit))
                          (+notebook--md-style-line bol text eol code))))
                    (goto-char bol)
                    (forward-line 1))))
              (setq h next))))))
    nil))

(defun +notebook--md-setup (on)
  "Turn markdown cell styling ON or off in the current buffer."
  (if on
      (progn
        (require 'markdown-mode nil t)  ; its faces
        (font-lock-add-keywords nil '((+notebook--md-fontify)) 'append)
        (add-hook 'font-lock-extend-region-functions #'+notebook--md-extend-region nil t))
    (font-lock-remove-keywords nil '((+notebook--md-fontify)))
    (remove-hook 'font-lock-extend-region-functions #'+notebook--md-extend-region t))
  (font-lock-flush))

;;; Mode

(defvar +notebook-mode-map (make-sparse-keymap))

(define-minor-mode +notebook-mode
  "`# %%' cells with inline Jupyter outputs."
  :keymap +notebook-mode-map
  (if +notebook-mode
      (progn
        (require 'code-cells)
        (code-cells-mode 1)
        (+notebook--md-setup t)
        (add-hook 'kill-buffer-hook #'+notebook--on-kill nil t))
    (code-cells-mode -1)
    (+notebook--md-setup nil)
    (+notebook/delete-all-outputs)
    (remove-hook 'kill-buffer-hook #'+notebook--on-kill t)))

;; Evil applies a minor mode's state keys (RET, the `,' notebook keys) only after
;; `evil-normalize-keymaps'. .ipynb buffers enable the mode after their major mode
;; (+notebook-ipynb-mode); evil-snipe's local mode used to refresh as a side effect.
(add-hook '+notebook-mode-hook #'evil-normalize-keymaps)

(defun +notebook--on-kill ()
  "Shut the kernel down when its last associated buffer goes away."
  (when-let* ((client (+jupyter-client)))
    (unless (cl-some (lambda (b) (and (not (eq b (current-buffer)))
                                      (eq (+jupyter-client b) client)))
                     (buffer-list))
      (ignore-errors (+jupyter-detach t)))))

(defun +notebook-mode-maybe ()
  "Enable `+notebook-mode' in python buffers that contain `# %%' cells."
  (require 'code-cells)
  (when (and (not +notebook-mode)
             (save-excursion (goto-char (point-min))
                             (re-search-forward code-cells-boundary-regexp nil t)))
    (+notebook-mode 1)))

(add-hook 'python-base-mode-hook #'+notebook-mode-maybe)

;; Replace code-cells' converter (drops outputs) with nbsync.
(setq auto-mode-alist (rassq-delete-all 'code-cells-convert-ipynb auto-mode-alist))
(add-to-list 'auto-mode-alist '("\\.ipynb\\'" . +notebook-ipynb-mode))

;;; Hydra (`,j'): pink, other keys keep working

(defun +notebook/hydra ()
  (interactive)
  (require 'hydra)
  (unless (fboundp '+notebook-hydra/body)
    (eval
     '(defhydra +notebook-hydra (:color pink :hint nil)
        "
 Cells  _j_/_k_ next/prev  _r_/_RET_ run  _l_ line  _a_ above  _A_ all  _x_ interrupt  _o_ output  _q_ quit"
        ("j" +notebook/next-cell)
        ("k" +notebook/prev-cell)
        ("RET" +notebook/run-cell)
        ("r" +notebook/run-cell)
        ("l" +notebook/run-line)
        ("a" +notebook/run-above)
        ("A" +notebook/run-all)
        ("x" +jupyter/interrupt)
        ("o" +notebook/show-output :exit t)
        ("q" nil :exit t)
        ("<escape>" nil :exit t))
     t))
  (funcall '+notebook-hydra/body))

;;; Keys

(map! :map +notebook-mode-map
      :n "RET" #'+notebook/run-cell
      :nv "]c" #'+notebook/next-cell
      :nv "[c" #'+notebook/prev-cell
      :nv "]b" #'+notebook/next-cell
      :nv "[b" #'+notebook/prev-cell
      :localleader
      :desc "Run cell"                 "e" #'+notebook/run-cell
      :desc "Run line"                 "l" #'+notebook/run-line
      :desc "Run motion/selection"     ";" #'+notebook:eval
      :desc "Re-run cell"              "r" #'+notebook/run-cell
      :desc "Run above (incl.)"        "a" #'+notebook/run-above
      :desc "Run all"                  "A" #'+notebook/run-all
      :desc "Re-run cells with output" "E" #'+notebook/rerun-all
      :desc "Output (focused)"         "o" #'+notebook/show-output
      :desc "Yank output"              "y" #'+notebook/yank-output
      :desc "Yank output to clipboard" "Y" #'+notebook/yank-output-clipboard
      :desc "Image in viewer"          "P" #'+notebook/image-popup
      :desc "HTML in browser"          "b" #'+notebook/open-html
      :desc "Toggle inline outputs"    "v" #'+notebook/toggle-outputs
      :desc "Delete cell output"       "d" #'+notebook/delete-output
      :desc "Delete all outputs"       "D" #'+notebook/delete-all-outputs
      :desc "Interrupt"                "x" #'+jupyter/interrupt
      :desc "Restart kernel"           "R" #'+jupyter/restart
      :desc "Restart + clear outputs"  "Z" #'+notebook/restart-clear
      :desc "Quit kernel + clear"      "q" #'+notebook/quit
      :desc "Kernel REPL buffer"       "p" #'+jupyter/pop-repl
      :desc "Write .ipynb"             "N" #'+notebook/export-ipynb
      :desc "Go to cell N"             "g" #'+notebook/goto-cell
      :desc "Cell mode (hydra)"        "j" #'+notebook/hydra)

(set-popup-rule! "^\\*jupyter-cell-output\\*" :size 0.4 :select t :quit t :ttl nil)
(set-popup-rule! "^\\*jupyter-repl" :size 0.35 :select t :quit nil :ttl nil)

(provide '+jupyter-cells)
;;; +jupyter-cells.el ends here
