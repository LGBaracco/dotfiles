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
;;
;; `,ji'/`,jI'/… set buffer-local `org-babel-default-header-args:jupyter-python'
;; (:session, :kernel, :async yes), start the session and inject the same wiring
;; as notebooks (sys.path, chdir, autoreload, project imports).

(require 'cl-lib)
(require '+jupyter-kernels)
(require '+jupyter-remote)

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

;;; Block navigation / text objects (only in buffers with jupyter blocks)

(defvar +jupyter-org-mode-map (make-sparse-keymap))

(define-minor-mode +jupyter-org-mode
  "Keys for Org files with Jupyter src blocks."
  :keymap +jupyter-org-mode-map)

(defun +jupyter-org-mode-maybe ()
  (when (save-excursion (goto-char (point-min))
                        (re-search-forward "^[ \t]*#\\+begin_src[ \t]+jupyter-" nil t))
    (+jupyter-org-mode 1)))

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
       :desc "Hydra"                        "j" #'+jupyter-org/hydra))

(provide '+jupyter-org)
;;; +jupyter-org.el ends here
