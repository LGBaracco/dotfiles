;;; lisp/+claude-remote.el -*- lexical-binding: t; -*-
;;
;; Claude Code (claude-code-ide) from TRAMP buffers. Claude can't run over TRAMP: its
;; file tools see only the local filesystem. So it runs here, in the host's sshfs
;; mount (`+remote-hosts' :mount, mounted on demand). It edits the project files
;; freely but runs nothing on the cluster, and no shell command in the mount, unless
;; the user allows it: its system prompt says so, and
;; claude/.claude/hooks/cluster-guard.py makes every such command a permission
;; prompt. Emacs keeps the TRAMP view:
;;
;;   session project dir       TRAMP (/ssh:jureca:/p/…): buffer→session lookup,
;;                             diagnostics and the Emacs MCP tools see TRAMP buffers
;;   Claude's cwd, lock file   the mount (/mnt/jureca/…)
;;   MCP traffic               paths rewritten at the boundary: Claude → Emacs mount
;;                             → TRAMP (remote sessions only); Emacs → Claude every
;;                             /ssh:HOST:REMOTE-ROOT of `+remote-hosts' → mount
;;
;; Local sessions are untouched (outbound rewriting only changes /ssh: paths of
;; `+remote-hosts', which a local session never gets). Advice targets are internals of
;; claude-code-ide (checked against 3e742ae); after an upstream update, start a session
;; from a TRAMP buffer and ask Claude to open a file to check the wiring still holds.

(require 'cl-lib)
(require 'subr-x)
(require '+remote)

(declare-function claude-code-ide-mcp-session-project-dir "claude-code-ide-mcp" (session))
(declare-function claude-code-ide-mcp-server-get-session-context "claude-code-ide-mcp-server")
(declare-function claude-code-ide--get-working-directory "claude-code-ide")
(declare-function claude-code-ide-mcp--active-sessions "claude-code-ide-mcp")
(declare-function auto-revert-handler "autorevert")
(defvar claude-code-ide-system-prompt)

;;; Path rewriting

(defun +claude-remote--to-mount (s)
  "S with each /ssh:[USER@]HOST:REMOTE-ROOT of `+remote-hosts' replaced by its mount."
  (if (not (string-search "/ssh:" s))
      s
    (let ((case-fold-search nil))
      (dolist (entry +remote-hosts s)
        (when-let* ((mount (plist-get (cdr entry) :mount)))
          (setq s (replace-regexp-in-string
                   (concat "/ssh:\\(?:[^@:/|]+@\\)?" (regexp-quote (car entry)) ":"
                           (regexp-quote (car mount)))
                   (cdr mount) s t t)))))))

(defun +claude-remote--to-tramp (s)
  "S as a TRAMP name when it is a path or file:// URI on a host's mount, else S."
  (cond ((+remote-mount-to-tramp s))
        ((and (string-prefix-p "file://" s) (+remote-mount-to-tramp (substring s 7)))
         (concat "file://" (+remote-mount-to-tramp (substring s 7))))
        (t s)))

(defun +claude-remote--map (fn tree)
  "TREE (JSON-like: alists, lists, vectors, strings) with FN applied to every string."
  (cond ((stringp tree) (funcall fn tree))
        ((or (vectorp tree) (proper-list-p tree))   ; mapcar: no recursion along long lists
         (let ((mapped (mapcar (lambda (x) (+claude-remote--map fn x)) tree)))
           (if (vectorp tree) (vconcat mapped) mapped)))
        ((consp tree) (cons (+claude-remote--map fn (car tree))   ; (key . value)
                            (+claude-remote--map fn (cdr tree))))
        (t tree)))

(defun +claude-remote--map-arguments (params)
  "PARAMS of a tools/call with mount paths in its arguments turned into TRAMP names."
  (let ((params (copy-alist params)))
    (setf (alist-get 'arguments params)
          (+claude-remote--map #'+claude-remote--to-tramp (alist-get 'arguments params)))
    params))

;;; Claude → Emacs (remote sessions only)

(defun +claude-remote--ide-tools-call-a (args)
  "openFile/openDiff/getDiagnostics/…: mount paths → TRAMP for remote sessions.
ARGS: (ID PARAMS &optional SESSION WS)."
  (pcase-let ((`(,id ,params ,session . ,rest) args))
    (if (and session (file-remote-p (claude-code-ide-mcp-session-project-dir session)))
        `(,id ,(+claude-remote--map-arguments params) ,session ,@rest)
      args)))

(defun +claude-remote--mcp-tools-call-a (fn params)
  "Emacs MCP tools (xref, imenu, tree-sitter…): TRAMP in, mount paths out."
  (let ((dir (plist-get (claude-code-ide-mcp-server-get-session-context) :project-dir)))
    (if (and dir (file-remote-p dir))
        (+claude-remote--map #'+claude-remote--to-mount
                             (funcall fn (+claude-remote--map-arguments params)))
      (funcall fn params))))

;;; Emacs → Claude

(defun +claude-remote--outbound-a (tree)
  (+claude-remote--map #'+claude-remote--to-mount tree))

(defun +claude-remote--notification-a (args)
  "ARGS: (METHOD PARAMS SESSION); selection / at-mention file paths → mount."
  (pcase-let ((`(,method ,params . ,rest) args))
    `(,method ,(+claude-remote--outbound-a params) ,@rest)))

(defun +claude-remote--uri-a (args)
  "`claude-code-ide-file-path-to-uri' hex-encodes the path: map it before."
  (cons (+claude-remote--to-mount (car args)) (cdr args)))

(defun +claude-remote--lockfile-a (args)
  "Lock file workspaceFolders: Claude's cwd (the mount). ARGS: (PORT PROJECT-DIR . REST)."
  (pcase-let ((`(,port ,dir . ,rest) args))
    `(,port ,(or (and (stringp dir) (+remote-tramp-to-mount dir)) dir) ,@rest)))

;;; Starting Claude

(defun +claude-remote--prompt (host tramp-dir mount)
  "System prompt telling Claude that MOUNT is TRAMP-DIR on HOST."
  (let ((remote (directory-file-name (file-local-name tramp-dir)))
        (roots (+remote-host-get host :mount)))
    (format "REMOTE PROJECT ON %1$s. The working directory %2$s is an sshfs mount of %1$s:%3$s (local %4$s = %5$s on %1$s). The user edits the same files in Emacs over TRAMP.
- Reading, searching and editing the project files with your file tools (Read, Edit, Write, Glob, Grep) is always allowed. Keep Glob/Grep to the directories you need: sshfs is slow.
- Run no commands on %1$s and no shell commands in this mount unless the user explicitly asked for or allowed that command. Otherwise say which command you would run and why, and let the user decide. The code, Python environments, containers, data and Slurm all live on %1$s, so running the code always needs that permission.
- Each such command shows the user a permission prompt (cluster-guard hook). A denial means: do not retry it or work around it (other hosts, scripts, executeCode).
- Once allowed: `ssh -o BatchMode=yes %1$s 'cd %3$s && <command>'` reuses the user's ssh master (no 2FA). Non-interactive ssh only puts ~/.local/bin on PATH; for modules (uv), $PROJECT or $SCRATCH use `ssh -o BatchMode=yes %1$s \"bash -ic 'cd %3$s && <command>'\"` and ignore its 'no job control' warning. Heavy work belongs in Slurm jobs, not on the login node.
- If ssh fails with 'Permission denied (keyboard-interactive)', the master connection expired: ask the user to reconnect from Emacs and stop."
            host mount remote (cdr roots) (car roots))))

(defun +claude-remote--start-session-a (&rest _)
  "Before starting Claude from a TRAMP buffer: mount its host's share, check coverage."
  (let ((dir (claude-code-ide--get-working-directory)))
    (when (file-remote-p dir)
      (let ((host (or (+remote-host-key (file-remote-p dir 'host))
                      (user-error "Claude: %s is not in `+remote-hosts' (no sshfs mount to run in)"
                                  (file-remote-p dir 'host)))))
        (+remote-mount-ensure host)
        (unless (+remote-tramp-to-mount dir)
          (user-error "Claude: %s is outside %s's sshfs mount (%s)"
                      (file-local-name dir) host (car (+remote-host-get host :mount))))))))

(defun +claude-remote--terminal-a (fn buffer-name working-dir &rest args)
  "Run Claude in the mount of a remote WORKING-DIR, with the remote system prompt."
  (if-let* (((file-remote-p working-dir))
            (host (+remote-host-key (file-remote-p working-dir 'host)))
            (mount (+remote-tramp-to-mount working-dir)))
      (let ((claude-code-ide-system-prompt
             (string-join (delq nil (list claude-code-ide-system-prompt
                                          (+claude-remote--prompt host working-dir mount)))
                          "\n\n")))
        (apply fn buffer-name mount args))
    (apply fn buffer-name working-dir args)))

;;; Reverting TRAMP buffers after Claude's edits

;; Doom's lazy auto-revert (`doom-auto-revert-buffer-h') never touches TRAMP buffers,
;; so a file Claude edited through the mount kept its old text in Emacs. While a
;; Claude session runs on a host, revert that host's buffers on switch (one stat over
;; the master; unmodified buffers only; never triggers a login).
(defun +claude-remote--session-on-host-p (host)
  (cl-some (lambda (s)
             (let ((dir (claude-code-ide-mcp-session-project-dir s)))
               (and (file-remote-p dir)
                    (equal (+remote-host-key (file-remote-p dir 'host)) host))))
           (claude-code-ide-mcp--active-sessions)))

(defun +claude-remote--revert-h ()
  (when-let* ((file buffer-file-name)
              ((file-remote-p file nil t))
              (host (+remote-host-key (file-remote-p file 'host)))
              ((+claude-remote--session-on-host-p host)))
    (require 'autorevert)
    (dlet ((auto-revert-mode t)
           (auto-revert-remote-files t))
      (auto-revert-handler))))

(add-hook 'doom-switch-buffer-hook #'+claude-remote--revert-h)
(add-hook 'doom-switch-window-hook #'+claude-remote--revert-h)

;;; Advice

(advice-add 'claude-code-ide--start-session :before #'+claude-remote--start-session-a)
(advice-add 'claude-code-ide--create-terminal-session :around #'+claude-remote--terminal-a)
(advice-add 'claude-code-ide-mcp--create-lockfile :filter-args #'+claude-remote--lockfile-a)
(advice-add 'claude-code-ide-mcp--handle-tools-call :filter-args #'+claude-remote--ide-tools-call-a)
(advice-add 'claude-code-ide-mcp-http-server--handle-tools-call :around #'+claude-remote--mcp-tools-call-a)
(advice-add 'claude-code-ide-mcp--make-response :filter-return #'+claude-remote--outbound-a)
(advice-add 'claude-code-ide-mcp--send-notification :filter-args #'+claude-remote--notification-a)
(advice-add 'claude-code-ide-file-path-to-uri :filter-args #'+claude-remote--uri-a)

(provide '+claude-remote)
;;; +claude-remote.el ends here
