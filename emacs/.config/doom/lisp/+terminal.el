;;; lisp/+terminal.el -*- lexical-binding: t; -*-
;;
;; Ghostel popups that open where the buffer's code runs:
;;
;;   C-t      remote shell when the buffer is remote: a TRAMP file, or a buffer,
;;            REPL or Org file attached to a Jupyter server on an ssh host
;;            (,i ,S ,I), in the server's root (else ~); a local shell otherwise
;;   SPC o t  always the local terminal
;;
;; Ghostel starts the shell through TRAMP when `default-directory' is remote (the
;; user's login shell, over the host's ssh ControlMaster: no second 2FA). Slurm
;; servers get a login-node shell (same filesystem). Remote popups carry @HOST in
;; their name, so a local and a remote terminal of one project can both be open.

(require 'cl-lib)
(require '+jupyter-remote)

(defun +terminal--rec ()
  "Record of the buffer's remote Jupyter server (`+jupyter-remote--servers')."
  (+jupyter-remote--load)
  (or
   ;; Buffers attached with ,i / ,S / ,I / ,k
   (and +jupyter-server (+jupyter-remote--rec-of-server +jupyter-server))
   ;; A kernel's REPL buffer: the server of a buffer sharing its client
   (when-let* ((client (+jupyter-client)))
     (cl-some (lambda (b)
                (let ((server (buffer-local-value '+jupyter-server b)))
                  (and server (eq (+jupyter-client b) client)
                       (+jupyter-remote--rec-of-server server))))
              (buffer-list)))
   ;; Org: blocks run in session /jpy:127.0.0.1#PORT:NAME on the forwarded port
   (when-let* ((args (bound-and-true-p org-babel-default-header-args:jupyter-python))
               (session (alist-get :session args))
               ((stringp session))
               ((string-match "\\`/jpy:[^#:]+#\\([0-9]+\\):" session))
               (lport (string-to-number (match-string 1 session))))
     (cl-find lport +jupyter-remote--servers :key (lambda (r) (plist-get r :lport))))))

(defun +terminal--remote-dir ()
  "TRAMP directory for this buffer's terminal, or nil for a local one."
  (if (file-remote-p default-directory)
      default-directory
    (when-let* ((rec (+terminal--rec))
                (host (plist-get rec :host)))   ; nil for URL servers (own tunnel)
      (format "/ssh:%s:%s" host (file-name-as-directory (or (plist-get rec :root) "~"))))))

(defun +terminal--popup-p ()
  (and (derived-mode-p 'ghostel-mode)
       (string-prefix-p "*doom:ghostel-popup" (buffer-name))))

(defun +terminal--host-in-name-a (name)
  "Put @HOST before NAME's <persp> when remote (ghostel-popup:x@host<main>)."
  (if-let* ((host (file-remote-p default-directory 'host))
            ((string-match "<[^<>]*>\\*\\'" name)))
      (concat (substring name 0 (match-beginning 0)) "@" host (substring name (match-beginning 0)))
    name))

(advice-add '+ghostel--buffer-name :filter-return #'+terminal--host-in-name-a)

;; No prefix arg to `+ghostel/toggle': its recreate branch reads an unbound
;; `buffer-name' variable.
(defun +terminal/toggle ()
  "Toggle the terminal popup: on the cluster for remote buffers, else local."
  (interactive)
  (if (+terminal--popup-p)
      ;; Close from inside: the shell may have cd'd, so the popup name can't be recomputed.
      (delete-window)
    (let ((default-directory (or (+terminal--remote-dir) default-directory)))
      (+ghostel/toggle))))

(defun +terminal/toggle-local ()
  "Toggle the local terminal popup (home directory when the buffer is remote)."
  (interactive)
  (if (and (+terminal--popup-p) (not (file-remote-p default-directory)))
      (delete-window)
    (let ((default-directory (if (file-remote-p default-directory)
                                 (expand-file-name "~/")
                               default-directory)))
      (+ghostel/toggle))))

(provide '+terminal)
;;; +terminal.el ends here
