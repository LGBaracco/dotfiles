;;; lisp/+jupyter-remote.el -*- lexical-binding: t; -*-
;;
;; Jupyter servers on ssh hosts (JURECA by default), driven from Emacs:
;;
;;   ,S       start a server on the login node and attach its default kernel
;;   C-u ,S   same, as a Slurm job on a compute node (partition/GPUs/time prompted)
;;   ,I       attach to a running server: one Emacs started (also after a restart),
;;            one started by hand (runtime file + squeue), or a URL/token
;;   ,Q       stop a server (kill / scancel) and drop its port-forward
;;   ,i       in a TRAMP buffer: attach the host's server, starting one if needed
;;
;; Everything runs over the ssh ControlMaster of the host (ssh_config: ControlMaster
;; auto + ControlPersist), so 2FA is entered once (TRAMP prompts in the minibuffer)
;; and port-forwards are added to that connection with `ssh -O forward' -- no
;; terminal running `tunnel'. The server comes from ~/.local/bin/start-server on the
;; host (dotfiles bash/); its token is generated here and passed in a 0600 file.
;; Kernels attached to a TRAMP buffer get the project wiring with the cluster
;; paths, so files edited over TRAMP are picked up by autoreload without syncing.

(require 'cl-lib)
(require 'subr-x)
(require '+jupyter-kernels)

(defcustom +jupyter-remote-host "jureca"
  "ssh destination used when the buffer is not a TRAMP buffer."
  :type 'string)

(defcustom +jupyter-remote-state-dir "~/.local/state/emacs-jupyter"
  "Directory on the remote host for tokens and server logs (created 0700)."
  :type 'string)

(defcustom +jupyter-remote-start-command "\"$HOME\"/.local/bin/start-server"
  "Remote command starting a Jupyter server (accepts --port --ip --token-file --root)."
  :type 'string)

(defcustom +jupyter-slurm-defaults
  '(:partition "dc-gpu" :account "jinm16" :gpus 4 :time "01:00:00")
  "Defaults for `C-u ,S' (Slurm compute-node server)."
  :type 'plist)

(defcustom +jupyter-remote-start-timeout 180
  "Seconds to wait for a new server to answer (first `uv run --with jupyter' is slow)."
  :type 'integer)

(defcustom +jupyter-remote-default-url "http://localhost:8888/?token="
  "Default for a manually entered server (the `tunnel' port)."
  :type 'string)

(defconst +jupyter-remote--state-file
  (expand-file-name "jupyter-remote.eld" (or (bound-and-true-p doom-state-dir) user-emacs-directory)))

(defvar +jupyter-remote--servers nil
  "Known servers: plists (:id :host :kind :node :port :pid :job :token :lport :root :label).
:kind is `login', `job' or `manual'. Runtime-only key :server holds the `jupyter-server'.")

;;; State

(defun +jupyter-remote--save ()
  "Persist the server records (tokens included, hence 0600)."
  (let ((records (mapcar (lambda (r) (cl-loop for (k v) on r by #'cddr
                                              unless (eq k :server) append (list k v)))
                         +jupyter-remote--servers)))
    (with-file-modes #o600
      (with-temp-file +jupyter-remote--state-file
        (let ((print-length nil) (print-level nil))
          (prin1 records (current-buffer)))))
    (set-file-modes +jupyter-remote--state-file #o600)))

(defun +jupyter-remote--load ()
  (unless +jupyter-remote--servers
    (when (file-readable-p +jupyter-remote--state-file)
      (setq +jupyter-remote--servers
            (ignore-errors (with-temp-buffer
                             (insert-file-contents +jupyter-remote--state-file)
                             (read (current-buffer))))))))

(defun +jupyter-remote--forget (rec)
  (setq +jupyter-remote--servers (delq rec +jupyter-remote--servers))
  (+jupyter-remote--save))

;;; ssh

(defun +jupyter-remote--dest (&optional dir)
  "ssh destination for DIR's TRAMP host, else `+jupyter-remote-host'."
  (let ((dir (or dir default-directory)))
    (if (file-remote-p dir)
        (let ((user (file-remote-p dir 'user)) (host (file-remote-p dir 'host)))
          (if user (concat user "@" host) host))
      +jupyter-remote-host)))

(defun +jupyter-remote--master-p (host)
  (eq 0 (call-process "ssh" nil nil nil "-O" "check" host)))

(defun +jupyter-remote--ensure-master (host)
  "Make sure HOST has a live ssh master; log in through TRAMP (2FA prompt) if not."
  (unless (+jupyter-remote--master-p host)
    (message "jupyter: logging in to %s…" host)
    (condition-case err
        (file-exists-p (format "/ssh:%s:~/" host))
      (error (message "jupyter: TRAMP login failed: %s" (error-message-string err))))
    (unless (+jupyter-remote--master-p host)
      (user-error "No ssh master for %s: check ControlMaster/ControlPath in ssh_config, or M-x +jupyter/ssh-login"
                  host))))

(defun +jupyter/ssh-login (&optional host)
  "Open a terminal running `ssh -fN HOST' to type the 2FA by hand (master stays up)."
  (interactive)
  (let* ((host (or host (+jupyter-remote--dest)))
         (buf (make-term (format "ssh-login %s" host) "ssh" nil "-fN" host)))
    (with-current-buffer buf (term-char-mode))
    (pop-to-buffer buf)))

(cl-defun +jupyter-remote--ssh (host command &key input callback)
  "Run shell COMMAND on HOST (BatchMode, over the master); INPUT goes to stdin.
CALLBACK gets (EXIT-CODE STDOUT STDERR)."
  (let* ((out (generate-new-buffer " *+jupyter-ssh*"))
         (err (generate-new-buffer " *+jupyter-ssh-err*"))
         (proc (make-process
                :name "+jupyter-ssh" :buffer out :stderr err :noquery t
                :connection-type 'pipe
                :command (list "ssh" "-o" "BatchMode=yes" "-T" host command)
                :sentinel
                (lambda (p _)
                  (unless (process-live-p p)
                    (let ((o (with-current-buffer out (buffer-string)))
                          (e (with-current-buffer err (buffer-string))))
                      (kill-buffer out)
                      (when (buffer-live-p err) (kill-buffer err))
                      (when callback
                        (funcall callback (process-exit-status p) o e))))))))
    (when input (process-send-string proc input))
    (process-send-eof proc)
    proc))

(defun +jupyter-remote--forward (rec)
  "Add REC's local port-forward to its host's master; return the local port."
  (let* ((host (plist-get rec :host))
         (lport (or (plist-get rec :lport) (car (+jupyter--free-ports 1))))
         (spec (format "127.0.0.1:%d:%s:%d" lport (plist-get rec :node) (plist-get rec :port))))
    (with-temp-buffer
      (unless (eq 0 (call-process "ssh" nil t nil "-O" "forward" "-L" spec host))
        ;; Port taken (stale forward of an older session): cancel it, else pick another.
        (call-process "ssh" nil nil nil "-O" "cancel" "-L" spec host)
        (erase-buffer)
        (unless (eq 0 (call-process "ssh" nil t nil "-O" "forward" "-L" spec host))
          (setq lport (car (+jupyter--free-ports 1))
                spec (format "127.0.0.1:%d:%s:%d" lport (plist-get rec :node) (plist-get rec :port)))
          (erase-buffer)
          (unless (eq 0 (call-process "ssh" nil t nil "-O" "forward" "-L" spec host))
            (error "jupyter: port-forward %s failed: %s" spec (string-trim (buffer-string)))))))
    (plist-put rec :lport lport)
    lport))

(defun +jupyter-remote--unforward (rec)
  (when-let* ((lport (plist-get rec :lport)))
    (call-process "ssh" nil nil nil "-O" "cancel" "-L"
                  (format "127.0.0.1:%d:%s:%d" lport (plist-get rec :node) (plist-get rec :port))
                  (plist-get rec :host))))

(defun +jupyter-remote--url (rec)
  (or (plist-get rec :base) (format "http://127.0.0.1:%d" (plist-get rec :lport))))

(defun +jupyter-remote--on-node (node cmd)
  "Shell snippet running CMD on NODE, from the master's login node."
  (format "if [ \"$(hostname)\" = %s ]; then %s; else ssh -o BatchMode=yes %s %s; fi"
          (shell-quote-argument node) cmd (shell-quote-argument node) (shell-quote-argument cmd)))

;;; Preflight

(defun +jupyter-remote--preflight (url token callback)
  "GET URL/api/kernelspecs with TOKEN; CALLBACK gets (ERR DEFAULT-KERNEL).
The token is sent as a header on stdin (stays out of `ps')."
  (let* ((out (generate-new-buffer " *+jupyter-curl*"))
         (proc (make-process
                :name "+jupyter-curl" :buffer out :noquery t :connection-type 'pipe
                :command (append (list "curl" "-sS" "-m" "5" "-w" "\n%{http_code}")
                                 (when token (list "-H" "@-"))
                                 (list (concat url "/api/kernelspecs")))
                :sentinel
                (lambda (p _)
                  (unless (process-live-p p)
                    (let* ((s (with-current-buffer out (buffer-string)))
                           (code (process-exit-status p))
                           (hostport (replace-regexp-in-string "\\`https?://" "" url)))
                      (kill-buffer out)
                      (funcall
                       callback
                       (cond
                        ((eq code 7) (format "nothing listening on %s" hostport))
                        ((eq code 28) (format "%s timed out" hostport))
                        ((not (eq code 0)) (format "curl failed (%d): %s" code (string-trim s)))
                        ((string-match "\n\\([0-9]+\\)\\'" s)
                         (pcase (string-to-number (match-string 1 s))
                           (200 nil)
                           ((or 401 403) (format "%s rejected the token" hostport))
                           (st (format "%s answered HTTP %d; not a Jupyter server?" hostport st))))
                        (t "unexpected curl output"))
                       (and (string-match "\\`\\(\\(?:.\\|\n\\)*\\)\n[0-9]+\\'" s)
                            (ignore-errors
                              (plist-get (json-parse-string (match-string 1 s) :object-type 'plist)
                                         :default))))))))))
    (when token
      (process-send-string proc (format "Authorization: token %s\n" token)))
    (process-send-eof proc)))

(defun +jupyter-remote--wait (url token timeout callback &optional alive-check)
  "Retry the preflight every 3 s until it passes or TIMEOUT s; CALLBACK (ERR DEFAULT).
ALIVE-CHECK, if given, is called with a function (ALIVE-P REASON) after failures."
  (let ((deadline (+ (float-time) timeout)))
    (cl-labels ((try ()
                  (+jupyter-remote--preflight
                   url token
                   (lambda (err default)
                     (cond ((null err) (funcall callback nil default))
                           ((> (float-time) deadline) (funcall callback err nil))
                           (alive-check
                            (funcall alive-check
                                     (lambda (alive reason)
                                       (if alive (run-with-timer 3 nil #'try)
                                         (funcall callback reason nil)))))
                           (t (run-with-timer 3 nil #'try)))))))
      (try))))

;;; Attaching kernels

(defun +jupyter-remote--server-object (rec)
  "`jupyter-server' for REC (token header set, no prompts)."
  (require 'jupyter)
  (require 'jupyter-server)
  (let* ((url (+jupyter-remote--url rec))
         (server (or (let ((s (plist-get rec :server)))
                       (and s (equal (oref s url) url) s))
                     (cl-find url jupyter--servers :key (lambda (s) (oref s url)) :test #'equal)
                     (jupyter-server :url url))))
    (when (plist-get rec :token)
      (oset server auth `(("Authorization" . ,(concat "token " (plist-get rec :token))))))
    (cl-pushnew server jupyter--servers)
    (plist-put rec :server server)
    server))

(defun +jupyter-remote--rec-of-server (server)
  (cl-find server +jupyter-remote--servers :key (lambda (r) (plist-get r :server))))

(defun +jupyter-remote--short (host)
  "First label of HOST (jrc0123.jureca -> jrc0123); IP addresses stay whole."
  (cond ((null host) "?")
        ((string-match-p "\\`[0-9.]+\\'" host) host)
        (t (car (split-string host "\\.")))))

(defun +jupyter-remote--bootstrap (rec)
  "Wiring for the current buffer: project paths when the buffer lives on REC's host."
  (if (and (file-remote-p default-directory)
           (equal (+jupyter-remote--dest) (plist-get rec :host)))
      (pcase-let ((`(,root . ,pyproject) (+jupyter-project-root)))
        (+jupyter-bootstrap-code root (+jupyter--project-name pyproject) (and pyproject t)))
    (string-join
     '("get_ipython().run_line_magic('load_ext', 'autoreload')"
       "get_ipython().run_line_magic('autoreload', '2')"
       "import os as _os, socket as _socket"
       "print(f'wire: remote host={_socket.gethostname()} cwd={_os.getcwd()}')")
     "\n")))

(defun +jupyter-remote--attach (rec &optional spec-name bootstrap)
  "Attach the current buffer to SPEC-NAME (default: server default) on REC."
  (let* ((server (+jupyter-remote--server-object rec))
         (specs (jupyter-kernelspecs server t))
         (name (or spec-name (plist-get (oref server kernelspecs) :default)
                   (jupyter-kernelspec-name (car specs))))
         (spec (or (cl-find name specs :key #'jupyter-kernelspec-name :test #'equal)
                   (user-error "No kernelspec %s on %s" name (plist-get rec :label))))
         (label (format "%s@%s" name (+jupyter-remote--short (plist-get rec :node)))))
    (+jupyter-detach t)
    (+jupyter--notify "starting %s…" label)
    (let ((client (let ((jupyter-long-timeout (max 60 jupyter-long-timeout)))
                    (jupyter-bootstrap-repl
                     (jupyter-client (jupyter-kernel :server server :spec spec) 'jupyter-repl-client)
                     label nil nil))))
      (+jupyter-attach client :name name :label label :server server
                       :bootstrap (or bootstrap (+jupyter-remote--bootstrap rec))))))

(defun +jupyter-remote--do-attach (rec attach-fn &optional spec-name)
  "Attach the current buffer to REC: ATTACH-FN (e.g. Org sessions) or a REPL kernel."
  (if attach-fn (funcall attach-fn rec) (+jupyter-remote--attach rec spec-name)))

(defun +jupyter-remote--connect (rec buffer &optional spec-name on-done attach-fn)
  "Forward REC's port, wait for the server, attach BUFFER (SPEC-NAME or default).
ATTACH-FN, if non-nil, is called with REC in BUFFER instead of attaching a kernel."
  (+jupyter-remote--ensure-master (plist-get rec :host))
  (+jupyter-remote--forward rec)
  (+jupyter-remote--save)
  (+jupyter-remote--wait
   (+jupyter-remote--url rec) (plist-get rec :token) +jupyter-remote-start-timeout
   (lambda (err _default)
     (if err
         (progn
           (message "jupyter: %s is not answering: %s" (plist-get rec :label) err)
           ;; Process/job gone: drop the record so ,i / ,S start a fresh server.
           (when (string-match-p "\\`\\(server exited\\|job \\)" err)
             (+jupyter-remote--unforward rec)
             (+jupyter-remote--forget rec)))
       (when (buffer-live-p buffer)
         (with-current-buffer buffer
           (condition-case e
               (progn (+jupyter-remote--do-attach rec attach-fn spec-name)
                      (when on-done (funcall on-done)))
             (error (message "jupyter: attach failed: %s" (error-message-string e))))))))
   (+jupyter-remote--alive-check rec)))

(defun +jupyter-remote--alive-check (rec)
  "Function checking that REC's server process/job still exists (between retries)."
  (pcase (plist-get rec :kind)
    ('login
     (lambda (k)
       (+jupyter-remote--ssh
        (plist-get rec :host)
        (format "%s 2>/dev/null || tail -n 15 %s"
                (+jupyter-remote--on-node (plist-get rec :node) (format "kill -0 %s" (plist-get rec :pid)))
                (plist-get rec :log))
        :callback (lambda (_code out _err)
                    (funcall k (string-empty-p (string-trim out))
                             (format "server exited:\n%s" out))))))
    ('job
     (lambda (k)
       (+jupyter-remote--ssh
        (plist-get rec :host)
        (format "squeue -h -j %s -o %%T" (plist-get rec :job))
        :callback (lambda (_code out _err)
                    (funcall k (string-match-p "RUNNING" out)
                             (format "job %s is %s" (plist-get rec :job)
                                     (if (string-empty-p (string-trim out)) "gone" (string-trim out))))))))
    (_ nil)))

;;; Starting servers

(defun +jupyter-remote--token ()
  "48 random hex characters."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (call-process "head" nil t nil "-c" "24" "/dev/urandom")
    (mapconcat (lambda (c) (format "%02x" c)) (buffer-string) "")))

(defun +jupyter-remote--read-slurm ()
  (let ((d +jupyter-slurm-defaults))
    (list :partition (read-string "Partition: " (plist-get d :partition))
          :account (read-string "Account: " (plist-get d :account))
          :gpus (read-number "GPUs: " (plist-get d :gpus))
          :time (read-string "Time limit: " (plist-get d :time)))))

(defun +jupyter-remote--start (host root slurm buffer &optional attach-fn)
  "Start a server on HOST (login node, or Slurm job when SLURM is a plist), attach BUFFER."
  (+jupyter-remote--ensure-master host)
  (let* ((id (format-time-string "%Y%m%d-%H%M%S"))
         (dir +jupyter-remote-state-dir)
         (token (+jupyter-remote--token))
         (port (+ 20000 (random 40000)))
         (tokfile (format "%s/token-%s" dir id))
         (log (format "%s/server-%s.log" dir id))
         (start (format "%s --port %d --ip 0.0.0.0 --token-file %s%s"
                        +jupyter-remote-start-command port tokfile
                        (if root (concat " --root " (shell-quote-argument root)) "")))
         (prep (format "mkdir -p %s && chmod 700 %s && umask 077 && cat > %s"
                       dir dir tokfile))
         (rec (list :id id :host host :port port :token token :root root :log log
                    :kind (if slurm 'job 'login))))
    (if (not slurm)
        (+jupyter-remote--ssh
         host
         (format "%s && hostname && { setsid nohup %s > %s 2>&1 < /dev/null & echo $!; }"
                 prep start log)
         :input token
         :callback
         (lambda (code out err)
           (pcase-let ((`(,node ,pid) (split-string out "\n" t)))
             (if (or (not (eq code 0)) (not pid))
                 (message "jupyter: starting the server on %s failed: %s" host (string-trim (concat out err)))
               (setq rec (plist-put rec :node node))
               (setq rec (plist-put rec :pid pid))
               (setq rec (plist-put rec :label (format "%s (login, port %d)" (+jupyter-remote--short node) port)))
               (push rec +jupyter-remote--servers)
               (+jupyter-remote--save)
               (message "jupyter: server starting on %s (pid %s)…" node pid)
               (+jupyter-remote--connect rec buffer nil nil attach-fn)))))
      (+jupyter-remote--ssh
       host
       (format "%s && sbatch --parsable -A %s -p %s -N 1%s -t %s -J emacs-jupyter -o %s --wrap %s"
               prep (plist-get slurm :account) (plist-get slurm :partition)
               (if (> (plist-get slurm :gpus) 0) (format " --gres=gpu:%d" (plist-get slurm :gpus)) "")
               (plist-get slurm :time) log (shell-quote-argument start))
       :input token
       :callback
       (lambda (code out err)
         (let ((job (car (split-string (string-trim out) ";"))))
           (if (or (not (eq code 0)) (string-empty-p job))
               (message "jupyter: sbatch failed: %s" (string-trim (concat out err)))
             (setq rec (plist-put rec :job job))
             (setq rec (plist-put rec :label (format "job %s (%s)" job (plist-get slurm :partition))))
             (push rec +jupyter-remote--servers)
             (+jupyter-remote--save)
             (+jupyter-remote--await-job rec buffer (float-time) attach-fn))))))))

(defun +jupyter-remote--await-job (rec buffer t0 &optional attach-fn)
  "Poll squeue until REC's job runs, then connect BUFFER."
  (+jupyter-remote--ssh
   (plist-get rec :host)
   (format "squeue -h -j %s -o '%%T %%N'" (plist-get rec :job))
   :callback
   (lambda (_code out _err)
     (pcase-let ((`(,state ,node) (split-string (string-trim out))))
       (cond
        ((equal state "RUNNING")
         (plist-put rec :node node)
         (plist-put rec :label (format "%s (job %s)" node (plist-get rec :job)))
         (+jupyter-remote--save)
         (message "jupyter: job %s running on %s; waiting for the server…" (plist-get rec :job) node)
         (+jupyter-remote--connect rec buffer nil nil attach-fn))
        ((member state '("PENDING" "CONFIGURING"))
         (message "jupyter: job %s %s (%ds)…" (plist-get rec :job) (downcase state)
                  (round (- (float-time) t0)))
         (run-with-timer 5 nil #'+jupyter-remote--await-job rec buffer t0 attach-fn))
        (t
         (message "jupyter: job %s is %s; see %s" (plist-get rec :job)
                  (if state (downcase state) "gone") (plist-get rec :log))
         (+jupyter-remote--forget rec)))))))

;;; Choosing servers

(defun +jupyter-remote--live-for-host (host)
  "Servers of HOST known in this session or saved."
  (+jupyter-remote--load)
  (cl-remove-if-not (lambda (r) (and (equal (plist-get r :host) host) (plist-get r :node)))
                    +jupyter-remote--servers))

(defun +jupyter-remote--runtime-dir (host)
  (concat (or (cdr (assoc (+jupyter-remote--short (car (last (split-string host "@"))))
                          +jupyter-remote-data-dirs))
              "~/.local/share/jupyter")
          "/runtime"))

(defun +jupyter-remote--discover (host callback)
  "Servers started by hand on HOST: CALLBACK gets a list of records."
  (+jupyter-remote--ssh
   host
   (format "for f in %s/jpserver-*.json; do [ -r \"$f\" ] && cat \"$f\" && echo; done; echo '@@'; squeue --me -h -o '%%i %%T %%N' 2>/dev/null"
           (+jupyter-remote--runtime-dir host))
   :callback
   (lambda (_code out _err)
     (pcase-let* ((`(,json ,squeue) (split-string out "^@@$"))
                  (nodes (cl-loop for l in (split-string (or squeue "") "\n" t)
                                  for f = (split-string l)
                                  when (equal (nth 1 f) "RUNNING") collect (nth 2 f)))
                  (infos (with-temp-buffer
                           (insert json)
                           (goto-char (point-min))
                           (let (acc)
                             (while (progn (skip-chars-forward " \t\n") (not (eobp)))
                               (push (ignore-errors (json-parse-buffer :object-type 'plist)) acc))
                             (delq nil (nreverse acc))))))
       (funcall
        callback
        (mapcar (lambda (i)
                  (let* ((url (plist-get i :url))
                         (h (and url (string-match "//\\([^:/]+\\)" url) (match-string 1 url)))
                         (node (if (member h '(nil "0.0.0.0" "localhost" "127.0.0.1" "::"))
                                   (if (= (length nodes) 1) (car nodes) nil)
                                 h)))
                    (list :id (format "manual-%s" (plist-get i :pid)) :host host :kind 'manual
                          :node node :port (plist-get i :port) :token (plist-get i :token)
                          :pid (plist-get i :pid) :root (plist-get i :root_dir)
                          :label (format "%s:%s (started by hand, pid %s)"
                                         (or node "?") (plist-get i :port) (plist-get i :pid)))))
                infos))))))

(defun +jupyter-remote--normalize (input)
  "URL from INPUT: URL, host:port[/?token=…] or a bare token (localhost:8888)."
  (let ((input (string-trim (or input ""))))
    (cond ((string-empty-p input) nil)
          ((string-match-p "\\`https?://" input) input)
          ((string-match-p "[:/]" input) (concat "http://" input))
          (t (concat +jupyter-remote-default-url input)))))

(defun +jupyter-remote--manual ()
  "Record for a server reached through a URL the user types (own tunnel)."
  (let* ((last (car (cl-remove-if-not (lambda (r) (eq (plist-get r :kind) 'url)) +jupyter-remote--servers)))
         (url (+jupyter-remote--normalize
               (read-string "Jupyter server (URL, host:port or token): "
                            (if last (plist-get last :url) +jupyter-remote-default-url)))))
    (unless url (user-error "No server"))
    (string-match "\\`\\(https?://[^/?#]+\\)" url)
    (let* ((base (match-string 1 url))
           (token (and (string-match "[?&]token=\\([^&#]*\\)" url)
                       (let ((tk (match-string 1 url))) (unless (string-empty-p tk) tk))))
           (hp (split-string (replace-regexp-in-string "\\`https?://" "" base) ":")))
      (list :id (format "url-%s" base) :kind 'url :url url :base base :host nil
            :node (car hp) :port (string-to-number (or (cadr hp) "80"))
            :token token :label (format "%s (URL)" (replace-regexp-in-string "\\`https?://" "" base))))))

;;; Commands

(defun +jupyter-remote-start-or-attach (&optional slurm attach-fn)
  "`,i' in a TRAMP buffer: attach the host's server, starting one if needed."
  (let* ((host (+jupyter-remote--dest))
         (live (+jupyter-remote--live-for-host host)))
    (cond
     (slurm (+jupyter-remote/start-server slurm attach-fn))
     ((and (not attach-fn) (+jupyter-client-live-p) +jupyter-server)
      (+jupyter--notify "%s is already attached (,k switches, ,R restarts)" +jupyter-kernel-label))
     (live
      (let ((rec (if (cdr live)
                     (let ((alist (mapcar (lambda (r) (cons (plist-get r :label) r)) live)))
                       (cdr (assoc (completing-read "Server: " alist nil t) alist)))
                   (car live))))
        (+jupyter-remote--connect rec (current-buffer) nil nil attach-fn)))
     (t (+jupyter-remote/start-server nil attach-fn)))))

(defun +jupyter-remote/start-server (&optional slurm attach-fn)
  "Start a Jupyter server on the buffer's host (login node; C-u: Slurm job) and attach."
  (interactive "P")
  (let* ((host (+jupyter-remote--dest))
         (root (when (file-remote-p default-directory)
                 (directory-file-name (file-local-name (car (+jupyter-project-root)))))))
    (+jupyter-remote--start host root (and slurm (+jupyter-remote--read-slurm)) (current-buffer) attach-fn)))

(defun +jupyter-remote/attach (&optional attach-fn)
  "Attach the buffer to a running server (its default kernel)."
  (interactive)
  (+jupyter-remote--load)
  (let* ((host (+jupyter-remote--dest))
         (buffer (current-buffer))
         (known (mapcar (lambda (r) (cons (plist-get r :label) r))
                        (cl-remove-if-not (lambda (r) (plist-get r :node)) +jupyter-remote--servers)))
         (choices (append known
                          (list (cons (format "Discover servers on %s…" host) 'discover)
                                (cons "URL / host:port / token…" 'manual))))
         (choice (cdr (assoc (completing-read "Jupyter server: " choices nil t) choices))))
    (pcase choice
      ('manual
       (let ((rec (+jupyter-remote--manual)))
         (+jupyter-remote--preflight
          (+jupyter-remote--url rec) (plist-get rec :token)
          (lambda (err _)
            (if err (message "jupyter: %s" err)
              (setq +jupyter-remote--servers
                    (cons rec (cl-remove (plist-get rec :id) +jupyter-remote--servers
                                         :key (lambda (r) (plist-get r :id)) :test #'equal)))
              (+jupyter-remote--save)
              (with-current-buffer buffer (+jupyter-remote--do-attach rec attach-fn)))))))
      ('discover
       (+jupyter-remote--ensure-master host)
       (+jupyter-remote--discover
        host
        (lambda (recs)
          (if (null recs)
              (message "jupyter: no running servers found on %s" host)
            (let* ((alist (mapcar (lambda (r) (cons (plist-get r :label) r)) recs))
                   (rec (cdr (assoc (completing-read "Server: " alist nil t) alist))))
              (unless (plist-get rec :node)
                (plist-put rec :node (read-string "Node running it: ")))
              (push rec +jupyter-remote--servers)
              (+jupyter-remote--connect rec buffer nil nil attach-fn))))))
      ((pred consp)
       (if (eq (plist-get choice :kind) 'url)
           (+jupyter-remote--preflight
            (+jupyter-remote--url choice) (plist-get choice :token)
            (lambda (err _)
              (if err (message "jupyter: %s" err)
                (with-current-buffer buffer (+jupyter-remote--do-attach choice attach-fn)))))
         (+jupyter-remote--connect choice buffer nil nil attach-fn))))))

(defun +jupyter-remote/stop-server ()
  "Stop a server (kill / scancel), drop its forward and detach buffers using it."
  (interactive)
  (+jupyter-remote--load)
  (let* ((current (and +jupyter-server (+jupyter-remote--rec-of-server +jupyter-server)))
         (alist (mapcar (lambda (r) (cons (plist-get r :label) r)) +jupyter-remote--servers))
         (rec (or (and current (y-or-n-p (format "Stop %s? " (plist-get current :label))) current)
                  (cdr (assoc (completing-read "Stop server: " alist nil t) alist)))))
    (unless rec (user-error "No server"))
    (dolist (b (buffer-list))
      (when (and (plist-get rec :server) (eq (buffer-local-value '+jupyter-server b) (plist-get rec :server)))
        (with-current-buffer b (+jupyter-detach nil))))
    (+jupyter-remote--unforward rec)
    (let ((host (plist-get rec :host)))
      (pcase (plist-get rec :kind)
        ('login (+jupyter-remote--ssh host (format "%s; rm -f %s/token-%s"
                                                   (+jupyter-remote--on-node
                                                    (plist-get rec :node) (format "kill %s" (plist-get rec :pid)))
                                                   +jupyter-remote-state-dir (plist-get rec :id))))
        ('job (+jupyter-remote--ssh host (format "scancel %s; rm -f %s/token-%s" (plist-get rec :job)
                                                 +jupyter-remote-state-dir (plist-get rec :id))))
        ('manual (when (y-or-n-p (format "Kill the hand-started server (pid %s on %s)? "
                                         (plist-get rec :pid) (plist-get rec :node)))
                   (+jupyter-remote--ssh host (+jupyter-remote--on-node
                                              (plist-get rec :node) (format "kill %s" (plist-get rec :pid))))))))
    (+jupyter-remote--forget rec)
    (message "jupyter: stopped %s" (plist-get rec :label))))

;;; Hooks used by +jupyter-kernels (`,k')

(defun +jupyter-remote--rec-for-buffer ()
  (+jupyter-remote--load)
  (or (and +jupyter-server (+jupyter-remote--rec-of-server +jupyter-server))
      (car (+jupyter-remote--live-for-host (+jupyter-remote--dest)))))

(defun +jupyter-remote-kernelspec-names ()
  "Kernelspec names of the buffer's server."
  (when-let* ((rec (+jupyter-remote--rec-for-buffer))
              (server (and (plist-get rec :lport) (+jupyter-remote--server-object rec))))
    (mapcar #'jupyter-kernelspec-name (jupyter-kernelspecs server t))))

(defun +jupyter-remote-start-kernel (name root pkg)
  "Attach kernelspec NAME of the buffer's server, wired for ROOT (PKG)."
  (let ((rec (or (+jupyter-remote--rec-for-buffer)
                 (user-error "No server for %s (,S starts one, ,I attaches)" (+jupyter-remote--dest)))))
    (unless (plist-get rec :server)
      (+jupyter-remote--ensure-master (plist-get rec :host))
      (+jupyter-remote--forward rec))
    (+jupyter-remote--attach rec name
                             (and (file-remote-p default-directory)
                                  (+jupyter-bootstrap-code root pkg (and pkg t))))))

;;; Keys

(after! python
  (map! :map python-base-mode-map
        :localleader
        :desc "Attach to a Jupyter server" "I" #'+jupyter-remote/attach
        :desc "Start Jupyter server"       "S" #'+jupyter-remote/start-server
        :desc "Stop Jupyter server"        "Q" #'+jupyter-remote/stop-server))

(provide '+jupyter-remote)
;;; +jupyter-remote.el ends here
