;;; lisp/+jupyter-org.el -*- lexical-binding: t; -*-
;;
;; Org notebooks: `jupyter-python' src blocks (ob-jupyter, from :lang org +jupyter)
;; on the same kernels as the cells buffers. Outputs, plots included, land under
;; each block and are saved in the .org file. Doom's org localleader already uses
;; most single keys, so everything lives under `,j':
;;
;;   ,ji project kernel (local uv) / host's server (TRAMP file)   ,jI attach a server
;;   ,jS start a server (C-u: Slurm)  ,jk pick a kernel   ,je run block (RET too)
;;   ,ja blocks up to here  ,jA buffer  ,jx interrupt  ,jR restart  ,jd/,jD results
;;   ,jo open result  ,jj hydra        ]c/[c blocks, ib/ab block text objects
;;   ,jN write foo.ipynb (with outputs)
;;
;; `,ji'/`,jI'/… set buffer-local `org-babel-default-header-args:jupyter-python'
;; (:session, :kernel, :async yes), start the session and inject the same wiring
;; as notebooks (sys.path, chdir, autoreload, project imports). Kernels never
;; start by themselves.
;;
;; .ipynb → .org: `,O' in an open notebook, or M-x +jupyter-org/from-ipynb (dired:
;; marked files). bin/nbsync.py writes the outputs as emacs-jupyter does
;; (#+RESULTS:, plots in `jupyter-org-resource-directory'), so re-running a block
;; replaces them. Local org notebooks show their plots on open (`zi' toggles).

(require 'cl-lib)
(require '+jupyter-kernels)
(require '+jupyter-remote)
(require '+jupyter-cells)                ; `+notebook--nbsync'

(defvar-local +jupyter-org--bootstrap nil "Wiring code of the buffer's session.")

;; Org 9.8 requires :pre-blank on drawers; jupyter's RESULTS drawer lacks it, so
;; results with a drawer (plots + text, tracebacks) fail with `wholenump nil'
;; and nothing is inserted (emacs-jupyter #607; drop once fixed upstream).
(defun +jupyter-org--results-drawer-blank-a (element)
  (when (and element (eq (org-element-type element) 'drawer))
    (unless (org-element-property :pre-blank element)
      (org-element-put-property element :pre-blank 0))
    (unless (org-element-property :post-blank element)
      (org-element-put-property element :post-blank 1)))
  element)

(with-eval-after-load 'jupyter-org-client
  (advice-add 'jupyter-org-results-drawer :filter-return #'+jupyter-org--results-drawer-blank-a))

(defun +jupyter-org--session-name ()
  (file-name-base (or buffer-file-name (buffer-name))))

(defun +jupyter-org--start (session kernel &optional bootstrap label)
  "Point jupyter-python blocks at SESSION / KERNEL, start the session, run BOOTSTRAP."
  (require 'ob-jupyter)
  (setq-local org-babel-default-header-args:jupyter-python
              `((:session . ,session) (:kernel . ,kernel) (:async . "yes")))
  (let* ((jupyter-long-timeout (max +jupyter-kernel-start-timeout jupyter-long-timeout))
         (repl (org-babel-jupyter-initiate-session
                session `((:session . ,session) (:kernel . ,kernel))))
         (client (buffer-local-value 'jupyter-current-client repl)))
    (setq-local +jupyter-kernel-name kernel
                +jupyter-kernel-label (or label kernel)
                +jupyter-org--bootstrap bootstrap)
    (+jupyter--modeline-setup)
    (+jupyter-org-mode 1)
    (when bootstrap (+jupyter-run-bootstrap bootstrap client))
    (+jupyter--notify "org blocks → %s" (or label kernel))))

(defun +jupyter-org--use-server (rec &optional spec-name)
  "Session on REC's server (its default kernel unless SPEC-NAME)."
  (let* ((server (+jupyter-remote--server-object rec))
         (_ (jupyter-kernelspecs server t))
         (name (or spec-name (plist-get (oref server kernelspecs) :default)))
         (url (url-generic-parse-url (+jupyter-remote--url rec)))
         (session (format "/jpy:%s#%d:%s" (url-host url) (url-port url) (+jupyter-org--session-name))))
    (+jupyter-org--start session name (+jupyter-remote--bootstrap rec)
                         (format "%s@%s" name (+jupyter-remote--short (plist-get rec :node))))))

(defun +jupyter-org/init (&optional slurm)
  "Project kernel for this org file (local), or the host's server (TRAMP file)."
  (interactive "P")
  (if (file-remote-p default-directory)
      (+jupyter-remote-start-or-attach slurm #'+jupyter-org--use-server)
    (pcase-let ((`(,root . ,pyproject) (+jupyter-project-root)))
      (cond
       ((+jupyter-on-fuse-p root)
        (user-error "%s is on an sshfs/FUSE mount: open it over TRAMP (/ssh:…) and use ,ji"
                    (abbreviate-file-name root)))
       (pyproject
        (+jupyter--warn-nix-venv root)
        (let* ((pkg (+jupyter--project-name pyproject))
               (name (+jupyter--kernel-name root pkg)))
          (+jupyter-ensure-kernelspec root name)
          (+jupyter-local-kernelspecs t)
          (+jupyter-org--start name name (+jupyter-bootstrap-code root pkg t))))
       (t (+jupyter-org/switch-kernel))))))

(defun +jupyter-org/attach ()
  "Point the blocks at a running Jupyter server."
  (interactive)
  (+jupyter-remote/attach #'+jupyter-org--use-server))

(defun +jupyter-org/start-server (&optional slurm)
  "Start a server on the file's host (C-u: Slurm job) for the blocks."
  (interactive "P")
  (+jupyter-remote/start-server slurm #'+jupyter-org--use-server))

(defun +jupyter-org/switch-kernel ()
  "Pick the kernel of this file's blocks (local spec, server spec or a server)."
  (interactive)
  (let* ((rec (and (file-remote-p default-directory) (+jupyter-remote--rec-for-buffer)))
         (items (append
                 (when rec
                   (mapcar (lambda (n) (cons (format "%s (server)" n) (list :server n)))
                           (ignore-errors (+jupyter-remote-kernelspec-names))))
                 (unless (file-remote-p default-directory)
                   (mapcar (lambda (s) (cons (jupyter-kernelspec-name s)
                                             (list :local (jupyter-kernelspec-name s))))
                           (+jupyter-local-kernelspecs)))
                 (list (cons "Jupyter server…" (list :remote t)))))
         (choice (cdr (assoc (completing-read "Kernel for org blocks: " items nil t) items))))
    (cond ((plist-get choice :remote) (+jupyter-org/attach))
          ((plist-get choice :server)
           (+jupyter-remote--forward rec)
           (+jupyter-org--use-server rec (plist-get choice :server)))
          (t (let ((n (plist-get choice :local)))
               (+jupyter-org--start n n))))))

(defun +jupyter-org/restart ()
  "Restart the kernel of the block at point; the wiring is re-injected."
  (interactive)
  (require 'jupyter-org-client)
  (let ((code +jupyter-org--bootstrap))
    (jupyter-org-with-src-block-client
     (let ((client jupyter-current-client))
       (jupyter-repl-restart-kernel client)
       (when code
         (run-with-timer 2 nil (lambda () (+jupyter-run-bootstrap code client))))))))

(defun +jupyter-org/remove-all-results ()
  (interactive)
  (org-babel-remove-result-one-or-many t))

(defun +jupyter-org/hydra ()
  (interactive)
  (require 'jupyter-org-extensions)
  (call-interactively 'jupyter-org-hydra/body))

;;; .ipynb ⇄ .org (bin/nbsync.py to-org / from-org)

(defun +jupyter-org--read-file (file)
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8)) (insert-file-contents file))
    (buffer-string)))

(defun +jupyter-org--write-file (file string &optional binary)
  (with-temp-buffer
    (when binary (set-buffer-multibyte nil))
    (insert string)
    (let ((coding-system-for-write (if binary 'binary 'utf-8-unix)))
      (write-region (point-min) (point-max) file nil 'silent))))

(defun +jupyter-org--revert-buffer-of (file)
  "Show FILE's new contents in its buffer, if it has one without unsaved edits."
  (when-let* ((buf (get-file-buffer file)))
    (with-current-buffer buf
      (unless (buffer-modified-p) (revert-buffer t t)))))

(defun +jupyter-org--ipynb-files ()
  "Notebooks to convert: marked in dired, this notebook, else prompt."
  (cond
   ((derived-mode-p 'dired-mode)
    (or (cl-remove-if-not (lambda (f) (string-suffix-p ".ipynb" f)) (dired-get-marked-files))
        (user-error "No .ipynb file marked")))
   ((and buffer-file-name (string-suffix-p ".ipynb" buffer-file-name))
    (when (buffer-modified-p) (user-error "Save the notebook first"))
    (list buffer-file-name))
   (t (list (read-file-name "Notebook: " nil nil t nil
                            (lambda (f) (or (file-directory-p f) (string-suffix-p ".ipynb" f))))))))

(defun +jupyter-org--ipynb-to-org (file)
  "Write FILE (.ipynb) as a sibling .org; return the .org, or nil when skipped."
  (require 'ob-core)
  (let ((target (concat (file-name-sans-extension file) ".org")))
    (when (or (not (file-exists-p target))
              (y-or-n-p (format "%s exists. Overwrite? " (abbreviate-file-name target))))
      (let* ((res (json-parse-string
                   (+notebook--nbsync
                    "to-org"
                    (json-serialize
                     (list :ipynb (+jupyter-org--read-file file)
                           :media (or (bound-and-true-p jupyter-org-resource-directory) "./.ob-jupyter/")
                           :min_lines org-babel-min-lines-for-block-output)))
                   :object-type 'plist :array-type 'list))
             (dir (file-name-directory (expand-file-name target))))
        (dolist (f (plist-get res :files))
          (let ((path (expand-file-name (plist-get f :path) dir)))
            (unless (file-exists-p path)  ; content-addressed (sha1) names
              (make-directory (file-name-directory path) t)
              (+jupyter-org--write-file path (base64-decode-string (plist-get f :b64)) t))))
        (+jupyter-org--write-file target (plist-get res :org))
        (+jupyter-org--revert-buffer-of target)
        target))))

;;;###autoload
(defun +jupyter-org/from-ipynb (files)
  "Convert FILES (.ipynb) to .org notebooks next to them, outputs included.
The .ipynb files stay. In dired: the marked files."
  (interactive (list (+jupyter-org--ipynb-files)))
  (let ((done (delq nil (mapcar #'+jupyter-org--ipynb-to-org files))))
    (when (derived-mode-p 'dired-mode) (revert-buffer))
    (pcase done
      ('() (message "jupyter: nothing converted"))
      (`(,one) (find-file one) (message "jupyter: wrote %s" (abbreviate-file-name one)))
      (_ (message "jupyter: wrote %d org notebooks" (length done))))))

(defun +jupyter-org--image-output (path)
  "nbsync output for the image at PATH (base64, except SVG text)."
  (let ((ext (downcase (or (file-name-extension path) ""))))
    (if (equal ext "svg")
        (list :kind "image" :mime "image/svg+xml" :data (+jupyter-org--read-file path))
      (list :kind "image"
            :mime (if (member ext '("jpg" "jpeg")) "image/jpeg" "image/png")
            :data (with-temp-buffer
                    (set-buffer-multibyte nil)
                    (let ((coding-system-for-read 'binary)) (insert-file-contents-literally path))
                    (base64-encode-region (point-min) (point-max) t)
                    (buffer-string))))))

(defun +jupyter-org--element-text (el)
  (string-trim-right
   (buffer-substring-no-properties
    (org-element-property :post-affiliated el)
    (save-excursion (goto-char (org-element-property :end el))
                    (skip-chars-backward " \t\n")
                    (point)))))

(defun +jupyter-org--outputs (el)
  "nbsync outputs of result element EL (images resolved against `default-directory')."
  (pcase (org-element-type el)
    ('drawer (mapcan #'+jupyter-org--outputs (org-element-contents el)))
    ((or 'fixed-width 'example-block)
     (list (list :kind "text" :text (org-element-property :value el))))
    ('export-block
     (let ((type (downcase (org-element-property :type el))))
       (list (list :kind (if (member type '("html" "latex" "markdown")) type "text")
                   :text (org-element-property :value el)))))
    ('keyword nil)                      ; bare `#+RESULTS:'
    ('paragraph
     (let ((images (org-element-map el 'link
                     (lambda (l)
                       (let ((path (org-element-property :path l)))
                         (and (equal (org-element-property :type l) "file")
                              (string-match-p (image-file-name-regexp) path)
                              path))))))
       (if images
           (mapcar (lambda (p)
                     (let ((file (expand-file-name p)))
                       (if (file-exists-p file)
                           (+jupyter-org--image-output file)
                         (list :kind "text" :text (format "[missing image: %s]" p)))))
                   images)
         (list (list :kind "text" :text (+jupyter-org--element-text el))))))
    (_ (list (list :kind "text" :text (+jupyter-org--element-text el))))))

(defun +jupyter-org/export-ipynb ()
  "Write this org notebook to a sibling .ipynb, outputs included.
`jupyter-*' src blocks become code cells, the prose markdown cells (pandoc).
An existing .ipynb keeps its metadata (kernelspec) and cell ids."
  (interactive)
  (unless (derived-mode-p 'org-mode) (user-error "Not an org buffer"))
  (unless buffer-file-name (user-error "Save the buffer first"))
  (require 'ob-core)
  (save-restriction
    (widen)
    (+jupyter-org--export-ipynb (concat (file-name-sans-extension buffer-file-name) ".ipynb"))))

(defun +jupyter-org--export-ipynb (target)
  (let* ((tree (org-element-parse-buffer))
         (src (current-buffer))
         (results (make-hash-table))  ; begin -> result element (affiliated #+RESULTS:)
         blocks cells cuts language)
    (org-element-map tree org-element-all-elements
      (lambda (e)
        (when (or (org-element-property :results e)
                  (and (eq (org-element-type e) 'keyword)
                       (equal (org-element-property :key e) "RESULTS")))
          (puthash (org-element-property :begin e) e results))))
    (setq blocks (org-element-map tree 'src-block
                   (lambda (b) (and (string-prefix-p "jupyter-" (or (org-element-property :language b) ""))
                                    b))))
    (unless blocks (user-error "No jupyter-* src blocks in this buffer"))
    (setq language (string-remove-prefix "jupyter-" (org-element-property :language (car blocks))))
    (cl-loop
     for b in blocks
     for i from 0
     for res = (gethash (org-element-property :end b) results)
     do (push (list :source (string-trim-right (or (nth 1 (org-babel-get-src-block-info t b)) "")
                                               "\n+")
                    :outputs (vconcat (and res (+jupyter-org--outputs res))))
              cells)
        (push (list (org-element-property :begin b)
                    (org-element-property :end (or res b))
                    (format "\nNBSYNCCELL%d\n\n" i))
              cuts))
    ;; Prose: the buffer with each block and its result replaced by a placeholder.
    (let ((org (with-temp-buffer
                 (insert-buffer-substring-no-properties src)
                 (dolist (c cuts)       ; last block first, so positions stay valid
                   (pcase-let ((`(,beg ,end ,text) c))
                     (delete-region beg end)
                     (goto-char beg)
                     (insert text)))
                 (buffer-string)))
          (old (and (file-exists-p target) (+jupyter-org--read-file target))))
      (+jupyter-org--write-file
       target
       (+notebook--nbsync
        "from-org"
        (json-serialize
         (list :org org :language language :old (or old :null)
               :cells (vconcat (nreverse cells))))))
      (+jupyter-org--revert-buffer-of target)
      (message "jupyter: wrote %s (%d code cells)" (abbreviate-file-name target) (length blocks)))))

;;; Block navigation / text objects (only in buffers with jupyter blocks)

(defvar +jupyter-org-mode-map (make-sparse-keymap))

(define-minor-mode +jupyter-org-mode
  "Keys for Org files with Jupyter src blocks."
  :keymap +jupyter-org-mode-map)

(defun +jupyter-org-mode-maybe ()
  (when (save-excursion (goto-char (point-min))
                        (re-search-forward "^[ \t]*#\\+begin_src[ \t]+jupyter-" nil t))
    (+jupyter-org-mode 1)
    ;; Saved plots (not over TRAMP: every image would be downloaded on open).
    (unless (file-remote-p default-directory)
      (org-display-inline-images))))

(add-hook 'org-mode-hook #'+jupyter-org-mode-maybe)

(defun +jupyter-org--block ()
  (let ((el (org-element-at-point)))
    (unless (eq (org-element-type el) 'src-block) (user-error "Not in a src block"))
    el))

(after! evil
  (evil-define-text-object +jupyter-org-inner-block (count &optional _beg _end _type)
    "Src block body."
    (let ((el (+jupyter-org--block)))
      (save-excursion
        (goto-char (org-element-property :begin el))
        (forward-line 1)
        (let ((beg (point)))
          (goto-char (org-element-property :end el))
          (skip-chars-backward " \t\n")
          (beginning-of-line)
          (evil-range beg (point) 'line)))))

  (evil-define-text-object +jupyter-org-outer-block (count &optional _beg _end _type)
    "Whole src block."
    (let ((el (+jupyter-org--block)))
      (evil-range (org-element-property :begin el) (org-element-property :end el) 'line)))

  (evil-define-key '(visual operator) +jupyter-org-mode-map
    "ib" #'+jupyter-org-inner-block
    "ab" #'+jupyter-org-outer-block))

;;; Keys

(map! :map +jupyter-org-mode-map
      :nv "]c" #'org-babel-next-src-block
      :nv "[c" #'org-babel-previous-src-block)

(map! :after org
      :map org-mode-map
      :localleader
      (:prefix ("j" . "jupyter")
       :desc "Project kernel / host server" "i" #'+jupyter-org/init
       :desc "Attach a Jupyter server"      "I" #'+jupyter-org/attach
       :desc "Start Jupyter server"         "S" #'+jupyter-org/start-server
       :desc "Stop Jupyter server"          "Q" #'+jupyter-remote/stop-server
       :desc "Pick kernel"                  "k" #'+jupyter-org/switch-kernel
       :desc "Run block"                    "e" #'org-babel-execute-src-block
       :desc "Run blocks up to here"        "a" #'jupyter-org-execute-to-point
       :desc "Run buffer"                   "A" #'org-babel-execute-buffer
       :desc "Interrupt"                    "x" #'jupyter-org-interrupt-kernel
       :desc "Restart kernel"               "R" #'+jupyter-org/restart
       :desc "Remove result"                "d" #'org-babel-remove-result
       :desc "Remove all results"           "D" #'+jupyter-org/remove-all-results
       :desc "Open result"                  "o" #'org-babel-open-src-block-result
       :desc "Write .ipynb"                 "N" #'+jupyter-org/export-ipynb
       :desc "Hydra"                        "j" #'+jupyter-org/hydra))

(provide '+jupyter-org)
;;; +jupyter-org.el ends here
