;;; lisp/+jupyter-lsp.el -*- lexical-binding: t; -*-
;;
;; ty for buffers whose kernel runs in a container image (atlas on JURECA). The
;; packages exist only inside the .sif, so ty runs inside it too:
;;
;;   local buffer                      -> ty server (as before)
;;   TRAMP buffer, kernel has an image -> apptainer exec <sif> <remote ty> server
;;   TRAMP buffer otherwise            -> remote ty server
;;
;; eglot starts the command on the host through TRAMP; ty comes from
;; `uv tool install ty' there (home is bind-mounted into the image). The image's
;; site-/dist-packages are passed as ty extra-paths (queried once per image), the
;; live replacement for Neovim's :KernelEnvSync extraction. Images are set with
;; `M-x +jupyter/kernel-image-set'; the kernel used before one is attached comes
;; from `+jupyter-lsp-host-kernels'. A kernel change restarts eglot when the
;; image changes (the analogue of the ty_otter restart).

(require 'cl-lib)
(require '+jupyter-kernels)

(defcustom +jupyter-lsp-host-kernels '(("jureca" . "atlas"))
  "Kernel assumed for TRAMP buffers of a host until one is attached."
  :type '(alist :key-type string :value-type string))

(defconst +jupyter-lsp--state-file
  (expand-file-name "jupyter-kernel-images.eld" (or (bound-and-true-p doom-state-dir) user-emacs-directory)))

(defvar +jupyter-lsp--images nil
  "Alist ((HOST . KERNEL) . (:sif PATH :env (:version V :paths [...]))).")

(defun +jupyter-lsp--load ()
  (unless +jupyter-lsp--images
    (setq +jupyter-lsp--images
          (ignore-errors (with-temp-buffer (insert-file-contents +jupyter-lsp--state-file)
                                           (read (current-buffer)))))))

(defun +jupyter-lsp--save ()
  (with-temp-file +jupyter-lsp--state-file
    (let ((print-length nil) (print-level nil))
      (prin1 +jupyter-lsp--images (current-buffer)))))

(defun +jupyter-lsp--host (&optional dir)
  (let ((h (file-remote-p (or dir default-directory) 'host)))
    (and h (car (split-string h "\\.")))))

(defun +jupyter-lsp--kernel ()
  "Kernel of this buffer (attached, else the host default)."
  (or +jupyter-kernel-name
      (cdr (assoc (+jupyter-lsp--host) +jupyter-lsp-host-kernels))))

(defun +jupyter-lsp--entry (&optional kernel)
  (+jupyter-lsp--load)
  (cdr (assoc (cons (+jupyter-lsp--host) (or kernel (+jupyter-lsp--kernel))) +jupyter-lsp--images)))

(defun +jupyter-lsp--remote-ty ()
  "Absolute path of ty on the buffer's host (PATH inside images may differ)."
  (or (executable-find "ty" t)
      (user-error "ty not found on %s: run `uv tool install ty' there" (+jupyter-lsp--host))))

(defun +jupyter-lsp--query-env (sif)
  "Python version and package dirs inside SIF (run on the buffer's host)."
  (with-temp-buffer
    (let ((code (process-file
                 "apptainer" nil t nil "exec" sif "python3" "-c"
                 "import sys, json; print(json.dumps({'version': '%d.%d' % sys.version_info[:2], 'paths': [p for p in sys.path if p.endswith(('site-packages', 'dist-packages'))]}))")))
      (unless (eq code 0)
        (user-error "apptainer exec %s python3 failed: %s" sif (string-trim (buffer-string))))
      (goto-char (point-max))
      (forward-line -1)
      (json-parse-buffer :object-type 'plist))))

;;;###autoload
(defun +jupyter/kernel-image-set (kernel sif)
  "Use container image SIF (path on this buffer's host) for KERNEL's LSP."
  (interactive
   (progn
     (unless (file-remote-p default-directory) (user-error "Run this from a buffer on the cluster (TRAMP)"))
     (list (read-string "Kernel: " (+jupyter-lsp--kernel))
           (file-local-name (read-file-name "Image (.sif): " nil nil t)))))
  (+jupyter-lsp--load)
  (message "jupyter: reading Python paths from %s…" (file-name-nondirectory sif))
  (let ((env (+jupyter-lsp--query-env sif))
        (key (cons (+jupyter-lsp--host) kernel)))
    (setf (alist-get key +jupyter-lsp--images nil nil #'equal) (list :sif sif :env env))
    (+jupyter-lsp--save)
    (message "jupyter: ty uses %s for %s (Python %s, %d package dirs)"
             (file-name-nondirectory sif) kernel (plist-get env :version) (length (plist-get env :paths)))
    (+jupyter-lsp--maybe-restart)))

(defvar +jupyter-lsp--contacts (make-hash-table :test 'equal)
  "Project root -> ty command eglot was started with.")

(defun +jupyter-lsp--root ()
  (if-let* ((p (project-current))) (project-root p) default-directory))

(defun +jupyter-lsp--compute-contact ()
  (if (not (file-remote-p default-directory))
      (list "ty" "server")
    (let ((ty (+jupyter-lsp--remote-ty))
          (entry (+jupyter-lsp--entry)))
      (if entry
          (list "apptainer" "exec" (plist-get entry :sif) ty "server")
        (list ty "server")))))

(defun +jupyter-lsp-contact (&optional _interactive _project)
  "eglot contact for python buffers (see the file commentary)."
  (let ((contact (+jupyter-lsp--compute-contact)))
    (puthash (+jupyter-lsp--root) contact +jupyter-lsp--contacts)
    contact))

(defun +jupyter-lsp--workspace-config (server)
  "ty settings: the image's Python version and package dirs for remote projects."
  (let ((default-directory (project-root (eglot--project server))))
    (when-let* (((file-remote-p default-directory))
                (entry (+jupyter-lsp--entry))
                (env (plist-get entry :env)))
      `(:ty (:configuration (:environment (:python-version ,(plist-get env :version)
                                          :extra-paths ,(vconcat (plist-get env :paths)))))))))

(defun +jupyter-lsp--maybe-restart ()
  "Restart eglot when the buffer's ty command (image) differs from the running one."
  (when (and (featurep 'eglot) (file-remote-p default-directory) (derived-mode-p 'python-base-mode))
    (when-let* ((server (eglot-current-server)))
      (unless (equal (+jupyter-lsp--compute-contact)
                     (gethash (+jupyter-lsp--root) +jupyter-lsp--contacts))
        (eglot-shutdown server)
        (eglot-ensure)))))

(add-hook '+jupyter-kernel-change-hook #'+jupyter-lsp--maybe-restart)

(after! eglot
  (setq-default eglot-workspace-configuration #'+jupyter-lsp--workspace-config))

(provide '+jupyter-lsp)
;;; +jupyter-lsp.el ends here
