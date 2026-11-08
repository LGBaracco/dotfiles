;;; lisp/+jupyter-kernels.el -*- lexical-binding: t; -*-
;;
;; Kernel layer shared by notebook buffers (+jupyter-cells), Org (+jupyter-org) and
;; Jupyter servers on remote hosts (+jupyter-remote). Port of the Neovim setup
;; (plugins/repl/molten.lua + config/python_project.lua):
;;
;; - `,i' in a local uv project: write a kernelspec `<pkg>' that runs
;;   `uv run --project ROOT --with ipykernel …' (byte-compatible with the specs
;;   Neovim writes, so both editors share them), open ROOT/repl.py on the right
;;   unless the buffer already has cells, start the kernel and inject the wiring
;;   (sys.path, chdir, autoreload, `from <mod> import *').
;; - `,i' in a TRAMP buffer: hand over to +jupyter-remote (server on the host).
;; - `,k': swap the buffer's kernel (project / server kernelspecs / local specs).
;; - Guards: no local uv kernel on sshfs/FUSE mounts (it would rebuild the
;;   cluster .venv), warning for a .venv built on the Nix python.
;; - Modeline: `󱄅 <kernel>' while a kernel is attached.

(require 'cl-lib)
(require 'subr-x)
(require 'json)

(defgroup +jupyter nil
  "Jupyter kernels, notebooks and remote servers."
  :group 'tools
  :prefix "+jupyter-")

(defcustom +jupyter-repl-file "repl.py"
  "Literate REPL file opened by `,i' at the project root (`# %%' cells)."
  :type 'string)

(defcustom +jupyter-skip-dirs
  '(".git" ".venv" "venv" ".tox" "node_modules" "__pycache__" ".mypy_cache"
    ".pytest_cache" ".ruff_cache" "dist" "build" "tests" "test" "docs")
  "Directories never star-imported by the kernel wiring."
  :type '(repeat string))

(defcustom +jupyter-remote-data-dirs
  '(("jureca" . "/p/project1/cjinm16/baracco1/home_ext/.local/share/jupyter"))
  "Jupyter data dir per TRAMP host: where the remote server reads kernelspecs.
Hosts not listed use ~/.local/share/jupyter."
  :type '(alist :key-type string :value-type string))

(defcustom +jupyter-kernel-start-timeout 90
  "Seconds to wait for a new kernel (first `uv run --with ipykernel' resolves packages)."
  :type 'integer)

(defconst +jupyter--spec-marker "nvim-molten-literate"
  "kernel.json metadata.managed_by of project specs (shared with Neovim).")

(defvar-local +jupyter-kernel-label nil "Modeline label of the kernel attached to this buffer.")
(defvar-local +jupyter-kernel-name nil "Kernelspec name of the kernel attached to this buffer.")
(defvar-local +jupyter-server nil "`jupyter-server' of the attached kernel, nil for local kernels.")
(defvar-local +jupyter--bootstrap nil "Wiring code of the attached kernel (re-run after restarts).")

(defvar +jupyter-kernel-change-hook nil
  "Run in a buffer after its kernel changed (attach, switch, shutdown).")

(defun +jupyter-client (&optional buffer)
  "Kernel client of BUFFER (default current); nil before emacs-jupyter loads."
  (and (boundp 'jupyter-current-client)
       (buffer-local-value 'jupyter-current-client (or buffer (current-buffer)))))

(defun +jupyter--notify (fmt &rest args)
  (message "jupyter: %s" (apply #'format fmt args)))

;;; Projects

(defun +jupyter-project-root (&optional dir)
  "Return (ROOT . PYPROJECT) for DIR (default `default-directory').
ROOT is the directory holding pyproject.toml, else the git root, else DIR.
PYPROJECT is nil without a pyproject.toml. Works on TRAMP paths."
  (let* ((dir (file-name-as-directory (expand-file-name (or dir default-directory))))
         (py (locate-dominating-file dir "pyproject.toml")))
    (if py
        (cons (file-name-as-directory (expand-file-name py))
              (expand-file-name "pyproject.toml" py))
      (cons (file-name-as-directory
             (expand-file-name (or (locate-dominating-file dir ".git") dir)))
            nil))))

(defun +jupyter--project-name (pyproject)
  "`[project] name' of PYPROJECT, or nil."
  (when (and pyproject (file-readable-p pyproject))
    (with-temp-buffer
      (insert-file-contents pyproject)
      (let (in-project name)
        (while (and (not name) (not (eobp)))
          (let ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
            (cond ((string-match "^[ \t]*\\[" line)
                   (setq in-project (string-match-p "^[ \t]*\\[project\\][ \t]*$" line)))
                  ((and in-project
                        (string-match "^[ \t]*name[ \t]*=[ \t]*[\"']\\([^\"']+\\)[\"']" line))
                   (setq name (match-string 1 line)))))
          (forward-line 1))
        name))))

(defun +jupyter--kernel-name (root pkg)
  "Kernel name for ROOT: the project name (PKG) or directory name, `-' → `_'."
  (string-replace "-" "_" (or pkg (file-name-nondirectory (directory-file-name root)))))

;;; Guards

(defun +jupyter--fuse-mounts ()
  "Mount points of FUSE filesystems (sshfs `mju'/`mws' …)."
  (ignore-errors
    (with-temp-buffer
      (insert-file-contents "/proc/mounts")
      (cl-loop for line in (split-string (buffer-string) "\n" t)
               for f = (split-string line " ")
               when (string-prefix-p "fuse" (nth 2 f))
               collect (file-name-as-directory
                        (replace-regexp-in-string
                         "\\\\\\([0-7]\\{3\\}\\)"
                         (lambda (m) (string (string-to-number (match-string 1 m) 8)))
                         (nth 1 f) t t))))))

(defun +jupyter-on-fuse-p (path)
  "Non-nil when local PATH lives on a FUSE mount."
  (and (not (file-remote-p path))
       (let ((p (file-name-as-directory (expand-file-name path))))
         (cl-some (lambda (m) (and (not (equal m "/")) (string-prefix-p m p)))
                  (+jupyter--fuse-mounts)))))

(defun +jupyter--warn-nix-venv (root)
  "Warn when ROOT/.venv was built on the Nix python (pyzmq/greenlet wheels break)."
  (let ((cfg (expand-file-name ".venv/pyvenv.cfg" root)))
    (when (file-readable-p cfg)
      (with-temp-buffer
        (insert-file-contents cfg)
        (when (re-search-forward "^[ \t]*home[ \t]*=[ \t]*.*\\(/nix/store\\|/etc/profiles\\)" nil t)
          (display-warning
           '+jupyter
           "Project .venv uses the Nix python; ipykernel wheels will fail. Run `uv python pin 3.12 && uv sync` (uv-managed CPython)."))))))

;;; Kernelspecs

(defun +jupyter--data-dir (&optional remote-root)
  "Jupyter data dir; on REMOTE-ROOT's host as a TRAMP file name."
  (if-let* ((remote (and remote-root (file-remote-p remote-root))))
      (concat remote
              (or (cdr (assoc (car (split-string (file-remote-p remote-root 'host) "\\."))
                              +jupyter-remote-data-dirs))
                  "~/.local/share/jupyter"))
    (let ((env (getenv "JUPYTER_DATA_DIR"))
          (xdg (getenv "XDG_DATA_HOME")))
      (expand-file-name
       (cond ((and env (not (string-empty-p env))) env)
             ((and xdg (not (string-empty-p xdg))) (expand-file-name "jupyter" xdg))
             (t "~/.local/share/jupyter"))))))

(defun +jupyter--kernel-argv (root)
  "argv of ROOT's project kernel: uv layers ipykernel over the project env at launch."
  (let ((uv (if (file-remote-p root)
                "uv"                    ; resolved in the server's environment
              (or (executable-find "uv") (user-error "`uv' not found on PATH")))))
    (vector uv "run" "--project" (directory-file-name (file-local-name root))
            "--with" "ipykernel" "python" "-Xfrozen_modules=off"
            "-m" "ipykernel_launcher" "-f" "{connection_file}")))

(defun +jupyter--read-json (file)
  (ignore-errors
    (with-temp-buffer
      (insert-file-contents file)
      (json-parse-buffer :object-type 'alist :array-type 'array :false-object :false))))

(defun +jupyter-ensure-kernelspec (root name)
  "Write NAME's kernel.json for ROOT (local, or on ROOT's TRAMP host). Idempotent."
  (let* ((dir (expand-file-name (concat "kernels/" name) (+jupyter--data-dir root)))
         (file (expand-file-name "kernel.json" dir))
         (argv (+jupyter--kernel-argv root))
         (current (and (file-readable-p file) (+jupyter--read-json file)))
         (meta (alist-get 'metadata current)))
    (unless (and current
                 (equal (alist-get 'argv current) argv)
                 (equal (alist-get 'display_name current) (concat name " (uv)"))
                 (equal (alist-get 'interrupt_mode current) "signal")
                 (equal (alist-get 'managed_by meta) +jupyter--spec-marker))
      (make-directory dir t)
      (with-temp-file file
        (insert (json-serialize
                 `((argv . ,argv)
                   (display_name . ,(concat name " (uv)"))
                   (language . "python")
                   (interrupt_mode . "signal")
                   (metadata . ((debugger . t) (managed_by . ,+jupyter--spec-marker)))))))
      (+jupyter--notify "kernel spec %S written (uv run --with ipykernel)" name))
    file))

(defun +jupyter--stale-spec-p (spec)
  "Non-nil for a managed project SPEC whose --project dir is gone."
  (let* ((plist (jupyter-kernelspec-plist spec))
         (argv (append (plist-get plist :argv) nil)))
    (and (equal (plist-get (plist-get plist :metadata) :managed_by) +jupyter--spec-marker)
         (when-let* ((dir (cadr (member "--project" argv))))
           (not (file-directory-p dir))))))

(defun +jupyter-local-kernelspecs (&optional refresh)
  "Local kernelspecs (`jupyter-kernelspec' structs), stale project specs removed."
  (require 'jupyter)
  (let ((default-directory (expand-file-name "~/")))
    (cl-remove-if #'+jupyter--stale-spec-p (jupyter-available-kernelspecs refresh))))

(defun +jupyter--local-kernelspec (name)
  (or (cl-find name (+jupyter-local-kernelspecs) :key #'jupyter-kernelspec-name :test #'equal)
      (cl-find name (+jupyter-local-kernelspecs t) :key #'jupyter-kernelspec-name :test #'equal)
      (user-error "No local kernelspec named %s" name)))

;;; Ports for local kernels
;; `jupyter-session-with-random-ports' borrows ports by starting the *default*
;; `python3' kernel through `python -m jupyter_client.kernelapp'; with no native
;; python3 kernel that fails ("`jupyter kernel` failed to show connection file
;; path"). Local kernels get their ports from Emacs instead; TRAMP launches keep
;; the upstream path.

(defun +jupyter--free-ports (n)
  "N distinct free TCP ports on 127.0.0.1 (listeners held until all are chosen)."
  (let ((procs (cl-loop repeat n collect
                        (make-network-process :name "+jupyter-port" :server t :noquery t
                                              :host "127.0.0.1" :service t :family 'ipv4))))
    (unwind-protect (mapcar (lambda (p) (process-contact p :service)) procs)
      (mapc #'delete-process procs))))

(defun +jupyter--session-with-local-ports-a (fn)
  (if (file-remote-p default-directory)
      (funcall fn)
    (let ((key (jupyter-new-uuid)))
      (pcase-let ((`(,shell ,iopub ,stdin ,control ,hb) (+jupyter--free-ports 5)))
        (jupyter-session
         :key key
         :conn-info (list :transport "tcp" :ip "127.0.0.1" :signature_scheme "hmac-sha256"
                          :key key :shell_port shell :iopub_port iopub :stdin_port stdin
                          :control_port control :hb_port hb))))))

(with-eval-after-load 'jupyter-env
  (advice-add 'jupyter-session-with-random-ports :around #'+jupyter--session-with-local-ports-a))

;;; Executing code

(cl-defun +jupyter-execute (code &key (client (+jupyter-client)) callbacks store-history)
  "Send CODE to CLIENT's kernel. CALLBACKS: alist of (\"msg_type\" FN).
`:handlers' keeps the REPL's own cell handlers out of the request (they error
with \"Cell for request not found\"); input_request still prompts."
  (unless client (user-error "No kernel attached (,i / ,I / ,k)"))
  (require 'jupyter)
  (jupyter-run-with-client client
    (jupyter-sent
     (jupyter-message-subscribed
      (jupyter-execute-request :code code :store-history store-history
                               :handlers '("input_request"))
      callbacks))))

(defun +jupyter-client-live-p (&optional client)
  (let ((client (or client (+jupyter-client))))
    (and client (ignore-errors (jupyter-kernel-alive-p client)))))

;;; Wiring (bootstrap)

(defun +jupyter--py-str (s)
  "S as a Python string literal (JSON strings are valid Python literals)."
  (json-encode-string s))

(defun +jupyter--import-targets (root pkg)
  "Top-level modules/packages of ROOT and ROOT/src (+ PKG's module name)."
  (let (targets)
    (cl-flet ((add (m) (when (and m (not (string-empty-p m)) (not (member m targets)))
                         (push m targets)))
              (scan (dir)
                (when (file-directory-p dir)
                  (dolist (e (directory-files-and-attributes dir nil "\\`[^.]" t))
                    (let ((name (car e)) (dirp (eq t (file-attribute-type (cdr e)))))
                      (unless (member name +jupyter-skip-dirs)
                        (cond ((and dirp (file-exists-p (expand-file-name "__init__.py" (expand-file-name name dir))))
                               (push name targets))
                              ((and (not dirp) (string-suffix-p ".py" name) (not (equal name "__init__.py")))
                               (push (file-name-sans-extension name) targets)))))))))
      (add (and pkg (string-replace "-" "_" pkg)))
      (scan root)
      (scan (expand-file-name "src" root)))
    (delete-dups (nreverse targets))))

(defun +jupyter-bootstrap-code (root &optional pkg with-imports)
  "Python wiring for ROOT: sys.path, chdir, autoreload, star imports (WITH-IMPORTS)."
  (let* ((lroot (directory-file-name (file-local-name root)))
         (imports (and with-imports (+jupyter--import-targets root pkg))))
    (string-join
     (append
      (list "import sys as _sys, os as _os, socket as _socket"
            "from pathlib import Path as _Path"
            (format "_root = _Path(%s)" (+jupyter--py-str lroot))
            "for _p in (_root, _root / 'src'):"
            "    if _p.is_dir() and str(_p) not in _sys.path:"
            "        _sys.path.insert(0, str(_p))"
            "if _root.is_dir():"
            "    _os.chdir(_root)"
            "get_ipython().run_line_magic('load_ext', 'autoreload')"
            "get_ipython().run_line_magic('autoreload', '2')")
      (cl-loop for m in imports
               append (list "try:"
                            (format "    import %s" m)
                            (format "    from %s import *" m)
                            "except Exception as _e:"
                            (format "    print('wire: skip import %s:', _e)" m)))
      (list (format "print(f'wire: host={_socket.gethostname()} root=%s imports=%s')"
                    lroot (string-join imports ","))))
     "\n")))

(defun +jupyter-run-bootstrap (code &optional client)
  "Run wiring CODE on CLIENT; echo its `wire:' output."
  (let ((out ""))
    (+jupyter-execute
     code :client client
     :callbacks
     `(("stream" ,(lambda (msg)
                    (setq out (concat out (plist-get (jupyter-message-content msg) :text)))))
       ("error" ,(lambda (msg)
                   (let ((c (jupyter-message-content msg)))
                     (+jupyter--notify "wiring failed: %s: %s"
                                       (plist-get c :ename) (plist-get c :evalue)))))
       ("execute_reply" ,(lambda (_msg)
                           (let ((lines (split-string out "\n" t)))
                             (when lines
                               (message "%s" (string-join (last lines 3) "\n"))))))))))

;;; Attaching kernels to buffers

(defun +jupyter--repl-name (name)
  (format "%s" name))

(defun +jupyter-start-local-kernel (name dir)
  "Start local kernelspec NAME with cwd DIR; return its REPL client."
  (require 'jupyter)
  (let* ((spec (+jupyter--local-kernelspec name))
         (default-directory (file-name-as-directory (expand-file-name dir)))
         (jupyter-long-timeout (max +jupyter-kernel-start-timeout
                                    (bound-and-true-p jupyter-long-timeout))))
    (+jupyter--notify "starting kernel %s…" name)
    (jupyter-bootstrap-repl
     (jupyter-client (jupyter-kernel :spec spec) 'jupyter-repl-client)
     (+jupyter--repl-name name) nil nil)))

(cl-defun +jupyter-attach (client &key name label server bootstrap)
  "Associate the current buffer with CLIENT and run BOOTSTRAP code."
  (when (derived-mode-p 'python-base-mode 'python-mode)
    (jupyter-repl-associate-buffer client))
  (setq-local jupyter-current-client client
              +jupyter-kernel-name name
              +jupyter-kernel-label (or label name)
              +jupyter-server server
              +jupyter--bootstrap bootstrap)
  (+jupyter--modeline-setup)
  (when bootstrap (+jupyter-run-bootstrap bootstrap client))
  (run-hooks '+jupyter-kernel-change-hook)
  (+jupyter--notify "ready (%s)" (or label name))
  client)

(defun +jupyter-detach (&optional shutdown)
  "Drop the current buffer's kernel; SHUTDOWN it and kill its REPL buffer."
  (let ((client (+jupyter-client)))
    (when (and shutdown client)
      (ignore-errors (jupyter-repl-shutdown-kernel client))
      (when-let* ((buf (ignore-errors (oref client buffer))))
        (when (buffer-live-p buf)
          ;; The REPL's buffer-local query asks to shut the kernel down (done above).
          (with-current-buffer buf
            (setq-local kill-buffer-query-functions nil)
            (kill-buffer buf)))))
    (when (bound-and-true-p jupyter-repl-interaction-mode)
      (jupyter-repl-interaction-mode -1))
    (setq-local jupyter-current-client nil
                +jupyter-kernel-name nil
                +jupyter-kernel-label nil
                +jupyter-server nil
                +jupyter--bootstrap nil)
    (run-hooks '+jupyter-kernel-change-hook)
    (force-mode-line-update)))

;;; Literate REPL buffer

(defun +jupyter--repl-template (name)
  (format "# %%%% [markdown]
# # Literate REPL (%s)
# Kernel wiring (sys.path, chdir, autoreload, project imports) is injected on attach.

# %%%%
# scratch

" name))

(defun +jupyter--show-right (buf)
  "Select a window showing BUF, or open BUF in a split on the right."
  (if-let* ((win (get-buffer-window buf)))
      (select-window win)
    (select-window (split-window-right))
    (switch-to-buffer buf)))

(defun +jupyter-open-repl-buffer (root name)
  "Open ROOT's repl file on the right; an unsaved template when missing."
  (let* ((path (expand-file-name +jupyter-repl-file root))
         (exists (file-exists-p path))
         (buf (find-file-noselect path)))
    (+jupyter--show-right buf)
    (unless (or exists (buffer-modified-p) (> (buffer-size) 0))
      (insert (+jupyter--repl-template name))
      (goto-char (point-max))
      (forward-line -2)
      (+jupyter--notify "opened in-memory %s (save to persist)" +jupyter-repl-file))
    (when (fboundp '+notebook-mode) (+notebook-mode 1))
    buf))

(defun +jupyter--cells-buffer-p ()
  "Non-nil when the current buffer is a notebook/cells buffer."
  (bound-and-true-p +notebook-mode))

;;; Commands

(declare-function +jupyter-remote-start-or-attach "+jupyter-remote")
(declare-function +jupyter-remote/attach "+jupyter-remote")
(declare-function +jupyter-remote-kernelspec-names "+jupyter-remote")
(declare-function +jupyter-remote-start-kernel "+jupyter-remote")

(defun +jupyter/init (&optional arg)
  "Attach the project kernel (local) or a server kernel (TRAMP buffer).
From a buffer without cells, open the project's repl file first.
ARG (remote only): submit a Slurm job instead of using the login node."
  (interactive "P")
  (if (file-remote-p default-directory)
      (+jupyter-remote-start-or-attach arg)
    (pcase-let ((`(,root . ,pyproject) (+jupyter-project-root)))
      (unless pyproject
        (user-error "Not a UV project (no pyproject.toml above %s). Run `uv init' there first"
                    (abbreviate-file-name root)))
      (when (+jupyter-on-fuse-p root)
        (user-error "%s is on an sshfs/FUSE mount: a local uv kernel would rebuild its .venv. Open it over TRAMP (/ssh:…) and use ,i / ,S"
                    (abbreviate-file-name root)))
      (+jupyter--warn-nix-venv root)
      (let* ((pkg (+jupyter--project-name pyproject))
             (name (+jupyter--kernel-name root pkg)))
        (+jupyter-ensure-kernelspec root name)
        (with-current-buffer (if (+jupyter--cells-buffer-p)
                                 (current-buffer)
                               (+jupyter-open-repl-buffer root name))
          (if (+jupyter-client-live-p)
              (+jupyter--notify "%s is already attached (,k switches, ,R restarts)" +jupyter-kernel-label)
            (+jupyter-attach (+jupyter-start-local-kernel name root)
                             :name name
                             :bootstrap (+jupyter-bootstrap-code root pkg t))))))))

(defun +jupyter--switch-candidates ()
  "Alist (LABEL . PLIST) of kernels `,k' can attach to the current buffer."
  (pcase-let* ((`(,root . ,pyproject) (+jupyter-project-root))
               (remote (file-remote-p default-directory))
               (pkg (+jupyter--project-name pyproject))
               (project (and pyproject (+jupyter--kernel-name root pkg)))
               (current +jupyter-kernel-name)
               (items nil))
    (cl-flet ((add (label plist)
                (push (cons (if (and (plist-get plist :name) (equal (plist-get plist :name) current))
                                (concat label " (current)")
                              label)
                            plist)
                      items)))
      (when (and project (or remote (not (+jupyter-on-fuse-p root))))
        (add (format "%s (uv project%s)" project (if remote ", on server" ""))
             (list :kind 'project :name project :root root :pkg pkg :remote remote)))
      (when (or remote +jupyter-server)
        (dolist (n (ignore-errors (+jupyter-remote-kernelspec-names)))
          (unless (equal n project)
            (add (format "%s (server)" n) (list :kind 'server :name n :root root :pkg pkg)))))
      (add "Jupyter server…" (list :kind 'remote))
      (unless remote
        (dolist (spec (+jupyter-local-kernelspecs))
          (let ((n (jupyter-kernelspec-name spec)))
            (unless (equal n project)
              (add n (list :kind 'local :name n :root root)))))))
    (nreverse items)))

(defun +jupyter/switch-kernel ()
  "Replace the buffer's kernel: project (uv), server kernelspec, local spec or a server."
  (interactive)
  (let* ((items (+jupyter--switch-candidates))
         (choice (cdr (assoc (completing-read "Kernel: " items nil t) items)))
         (kind (plist-get choice :kind))
         (name (plist-get choice :name))
         (root (plist-get choice :root)))
    (cond
     ((eq kind 'remote) (+jupyter-remote/attach))
     ((and name (equal name +jupyter-kernel-name) (+jupyter-client-live-p))
      (+jupyter--notify "%s is already attached (,R restarts it)" name))
     ((memq kind '(project server))
      (when (eq kind 'project)
        (+jupyter-ensure-kernelspec root name))
      (if (or (plist-get choice :remote) (eq kind 'server))
          (+jupyter-remote-start-kernel name root (plist-get choice :pkg))
        (+jupyter--warn-nix-venv root)
        (+jupyter-detach t)
        (+jupyter-attach (+jupyter-start-local-kernel name root)
                         :name name
                         :bootstrap (+jupyter-bootstrap-code root (plist-get choice :pkg) t))))
     (t
      (+jupyter-detach t)
      (+jupyter-attach (+jupyter-start-local-kernel name (or root default-directory))
                       :name name)))))

(defun +jupyter/interrupt ()
  (interactive)
  (jupyter-repl-interrupt-kernel (or (+jupyter-client) (user-error "No kernel attached"))))

(defun +jupyter/restart ()
  "Restart the kernel; the wiring (sys.path, imports, autoreload) is re-injected."
  (interactive)
  (let ((client (or (+jupyter-client) (user-error "No kernel attached")))
        (code +jupyter--bootstrap))
    (jupyter-repl-restart-kernel client)
    (when code
      (run-with-timer 2 nil (lambda ()
                              (when (ignore-errors (jupyter-kernel-alive-p client))
                                (+jupyter-run-bootstrap code client)))))))

(defun +jupyter/shutdown ()
  "Shut down the buffer's kernel."
  (interactive)
  (unless (+jupyter-client) (user-error "No kernel attached"))
  (+jupyter-detach t))

(defun +jupyter/pop-repl ()
  "Show the attached kernel's REPL buffer."
  (interactive)
  (let ((buf (and (+jupyter-client) (oref (+jupyter-client) buffer))))
    (unless (buffer-live-p buf) (user-error "No kernel attached"))
    (pop-to-buffer buf)))

;;; Modeline

(defface +jupyter-modeline-idle '((t :inherit success)) "Kernel idle.")
(defface +jupyter-modeline-busy '((t :inherit warning)) "Kernel busy.")

(defun +jupyter--modeline ()
  (when +jupyter-kernel-label
    (let ((state (and (+jupyter-client)
                      (ignore-errors (oref (+jupyter-client) execution-state)))))
      (propertize (format " 󱄅 %s " +jupyter-kernel-label)
                  'face (if (equal state "busy") '+jupyter-modeline-busy '+jupyter-modeline-idle)
                  'help-echo (format "Jupyter kernel %s (%s)" +jupyter-kernel-label (or state "?"))))))

(defun +jupyter--modeline-setup ()
  (unless (member '(:eval (+jupyter--modeline)) mode-line-misc-info)
    (setq-local mode-line-misc-info (cons '(:eval (+jupyter--modeline)) mode-line-misc-info))))

;;; Keys (every python buffer; notebook keys live in +jupyter-cells)

(after! python
  (map! :map python-base-mode-map
        :localleader
        "e" nil                         ; Doom's pipenv prefix (uv projects here)
        :desc "Jupyter init (project / server)" "i" #'+jupyter/init
        :desc "Switch kernel"                   "k" #'+jupyter/switch-kernel))

(provide '+jupyter-kernels)
;;; +jupyter-kernels.el ends here
