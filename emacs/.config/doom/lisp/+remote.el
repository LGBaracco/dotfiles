;;; lisp/+remote.el -*- lexical-binding: t; -*-
;;
;; Remote hosts (JSC clusters), shared by the Jupyter, LSP, terminal and Claude glue:
;;
;;   `+remote-hosts'        one entry per ssh_config alias: sshfs share, Slurm defaults,
;;                          kernel for ty, Jupyter data dir. Adding a host = one entry.
;;   dashboard `c', SPC o h pick a host, open its ~ over TRAMP in dirvish. This is the
;;                          all-remote workflow: TRAMP buffers get the host's Jupyter
;;                          servers (,i ,S), shell (C-t), ty and Claude (SPC o c).
;;                          Local files + remote kernel (,S from a local buffer) stay as is.
;;   `+remote-mount-ensure' mount a host's sshfs share (Claude runs on it, +claude-remote).
;;
;; All ssh traffic rides the host's ControlMaster (ssh_config), so 2FA is typed once.

(require 'cl-lib)
(require 'subr-x)

(defgroup +remote nil
  "Remote hosts over ssh, TRAMP and sshfs."
  :group 'tools
  :prefix "+remote-")

(defcustom +remote-hosts
  '(("jureca"
     :mount ("/p/" . "/mnt/jureca/")
     :slurm (:partition "dc-gpu" :account "jinm16" :gpus 4 :time "01:00:00")
     :kernel "atlas"
     :data-dir "/p/project1/cjinm16/baracco1/home_ext/.local/share/jupyter")
    ("jupiter"
     :mount ("/e/" . "/mnt/jupiter/")
     :slurm (:partition "booster" :account "brainfm" :gpus 4 :time "01:00:00")
     :kernel "atlas"))
  "Remote hosts by ssh_config alias, which is also the TRAMP host (/ssh:ALIAS:).
Properties:
  :mount     (REMOTE-DIR . LOCAL-DIR): sshfs share of `+remote-mount-ensure'
             (the same as the fish aliases mjr/mju)
  :slurm     defaults for `C-u ,S' (:partition :account :gpus :time)
  :kernel    kernel ty assumes for TRAMP buffers until one is attached
  :data-dir  Jupyter data dir (kernelspecs, runtime files). Default: what
             `start-server --data-dir' prints on the host, else ~/.local/share/jupyter"
  :type '(alist :key-type string :value-type plist))

(defvar +remote--last-host nil "Host last picked with `+remote-read-host'.")

(defvar savehist-additional-variables)
(with-eval-after-load 'savehist
  (add-to-list 'savehist-additional-variables '+remote--last-host))

(declare-function +jupyter--fuse-mounts "+jupyter-kernels")
(declare-function +jupyter-remote--ensure-master "+jupyter-remote")
(declare-function dirvish "dirvish")

;;; Hosts

(defun +remote-host-key (host)
  "Name of HOST's entry in `+remote-hosts' (HOST: alias, user@alias or FQDN), or nil."
  (when host
    (let ((h (car (last (split-string host "@")))))
      (or (car (assoc h +remote-hosts))
          (cl-loop for entry in +remote-hosts
                   when (member (car entry) (split-string h "\\.")) return (car entry))))))

(defun +remote-host-get (host prop)
  "Property PROP of HOST's entry in `+remote-hosts'."
  (plist-get (cdr (assoc (+remote-host-key host) +remote-hosts)) prop))

(defun +remote-master-p (host)
  "Non-nil when HOST has a live ssh master connection."
  (eq 0 (call-process "ssh" nil nil nil "-O" "check" host)))

(defun +remote-default-host ()
  "Host last picked, else the first of `+remote-hosts'."
  (or (car (member +remote--last-host (mapcar #'car +remote-hosts)))
      (caar +remote-hosts)))

(defun +remote-read-host (&optional prompt)
  "Pick a host of `+remote-hosts' (no prompt when there is one) and remember it."
  (let ((names (mapcar #'car +remote-hosts)))
    (setq +remote--last-host
          (if (null (cdr names))
              (car names)
            (let* ((status (mapcar (lambda (h)
                                     (cons h (if (+remote-master-p h) "connected" "2FA needed")))
                                   names))
                   (default (+remote-default-host))
                   (completion-extra-properties
                    `(:annotation-function
                      ,(lambda (c) (concat "  " (propertize (cdr (assoc c status)) 'face 'completions-annotations))))))
              (completing-read (format-prompt (or prompt "Host") default)
                               names nil t nil nil default))))))

;;; Jupyter data dir

(defvar +remote--data-dirs (make-hash-table :test 'equal)
  "TRAMP prefix -> Jupyter data dir printed by `start-server --data-dir'.")

(defun +remote-data-dir (dir)
  "Jupyter data dir on the host of DIR (a TRAMP file name), as a remote local name."
  (let ((prefix (file-remote-p dir)))
    (or (+remote-host-get (file-remote-p dir 'host) :data-dir)
        (gethash prefix +remote--data-dirs)
        (let* ((default-directory (concat prefix "~/"))
               (out (with-temp-buffer
                      (and (eq 0 (ignore-errors
                                   (process-file "sh" nil '(t nil) nil "-c"
                                                 "\"$HOME\"/.local/bin/start-server --data-dir")))
                           (car (last (split-string (buffer-string) "\n" t)))))))
          (if (and out (string-prefix-p "/" out))
              (puthash prefix out +remote--data-dirs)
            (message "remote: %s has no `start-server --data-dir' (pull the dotfiles there); using ~/.local/share/jupyter"
                     prefix)
            "~/.local/share/jupyter")))))

;;; sshfs

(defun +remote-tramp-to-mount (file)
  "Path of TRAMP FILE on its host's sshfs mount, or nil when no mount covers it."
  (when-let* (((file-remote-p file))
              (mount (+remote-host-get (file-remote-p file 'host) :mount)))
    (let ((local (file-local-name (expand-file-name file))))
      (cond ((string-prefix-p (car mount) local)
             (concat (cdr mount) (substring local (length (car mount)))))
            ((equal (file-name-as-directory local) (car mount))
             (cdr mount))))))

(defun +remote-mount-to-tramp (file)
  "TRAMP file name of FILE when it lies on a host's sshfs mount, else nil."
  (cl-loop for (host . props) in +remote-hosts
           for mount = (plist-get props :mount)
           ;; The mount dir itself, written without its trailing slash
           for f = (if (and mount (equal file (directory-file-name (cdr mount)))) (cdr mount) file)
           when (and mount (string-prefix-p (cdr mount) f))
           return (concat "/ssh:" host ":" (car mount) (substring f (length (cdr mount))))))

(defun +remote--answering-p (dir)
  (eq 0 (call-process "timeout" nil nil nil "5" "stat" "-t" (directory-file-name dir))))

(defun +remote-mount-ensure (host)
  "Mount HOST's sshfs share unless it is mounted and answering; return the mount dir."
  (pcase-let* ((`(,rdir . ,ldir)
                (or (+remote-host-get host :mount)
                    (user-error "No :mount for %s in `+remote-hosts'" host)))
               (mounted (member (file-name-as-directory ldir) (+jupyter--fuse-mounts))))
    (unless (and mounted (+remote--answering-p ldir))
      (when mounted                     ; stale (sshfs died, laptop slept)
        (call-process "fusermount3" nil nil nil "-uz" (directory-file-name ldir)))
      (unless (file-directory-p ldir)
        (user-error "Mount point %s is missing: sudo install -d -o \"$USER\" -g \"$USER\" %s"
                    ldir (directory-file-name ldir)))
      (+jupyter-remote--ensure-master host)
      (message "remote: mounting %s:%s on %s…" host rdir ldir)
      ;; ssh_config gives user, key and ControlPath: sshfs's ssh joins the master.
      (with-temp-buffer
        (unless (eq 0 (call-process "timeout" nil t nil "30" "sshfs"
                                    (concat host ":" rdir) (directory-file-name ldir) "-o"
                                    "follow_symlinks,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,ConnectTimeout=10"))
          (user-error "sshfs %s:%s failed: %s" host rdir (string-trim (buffer-string))))))
    ldir))

;;; Commands

(defun +remote/open-host (host)
  "Open HOST's home directory over TRAMP in dirvish (2FA prompt when not connected)."
  (interactive (list (+remote-read-host "Open remote host")))
  (dirvish (format "/ssh:%s:~/" host)))

(provide '+remote)
;;; +remote.el ends here
