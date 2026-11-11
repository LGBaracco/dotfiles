;;; lisp/+keys.el -*- lexical-binding: t; -*-
;;
;; Neovim-style keys. Baseline: ~/dotfiles/neovim/.config/nvim
;;   config/keymaps.lua, plugins/{files,git,dap,editor}.lua, plugins/repl/*.lua
;;
;; Rule: where a Doom leader prefix is shared with nvim (b f g w d), the nvim key
;; wins and non-colliding Doom keys stay. Doom prefixes that nvim replaces are
;; removed: SPC c (code -> SPC l), SPC s (search -> SPC f). Emacs-only prefixes
;; (h q p o t n i TAB ...) are untouched. Localleader `,' maps live with their
;; features (lisp/+jupyter-*.el); LaTeX's vimtex-style `,l' group is at the end.

(require 'hydra)

;;; Helpers ------------------------------------------------------------------

(defun +window/resize (dir)
  "Move the window divider toward DIR (smart-splits semantics)."
  (pcase dir
    ('left  (if (window-in-direction 'right) (evil-window-decrease-width 3) (evil-window-increase-width 3)))
    ('right (if (window-in-direction 'right) (evil-window-increase-width 3) (evil-window-decrease-width 3)))
    ('down  (if (window-in-direction 'below) (evil-window-increase-height 2) (evil-window-decrease-height 2)))
    ('up    (if (window-in-direction 'below) (evil-window-decrease-height 2) (evil-window-increase-height 2)))))

(defun +window/resize-left ()  (interactive) (+window/resize 'left))
(defun +window/resize-right () (interactive) (+window/resize 'right))
(defun +window/resize-down ()  (interactive) (+window/resize 'down))
(defun +window/resize-up ()    (interactive) (+window/resize 'up))

(defun +buffer/revert-no-confirm ()
  "Reload the buffer from disk without asking (nvim :e!)."
  (interactive)
  (revert-buffer :ignore-auto :noconfirm))

(defun +buffer/kill-discard ()
  "Kill the buffer, discarding unsaved changes (nvim :bdelete!)."
  (interactive)
  (set-buffer-modified-p nil)
  (kill-current-buffer))

(defun +consult/pickers ()
  "M-x narrowed to consult commands (nvim :Telescope)."
  (interactive)
  (minibuffer-with-setup-hook (lambda () (insert "consult- "))
    (call-interactively #'execute-extended-command)))

;; Surround (nvim-surround with no default maps, `gz' family; plugins/editor.lua)
(evil-define-operator +evil:comment-block (beg end)
  "Toggle a block comment over the motion (Comment.nvim `gb')."
  :move-point nil
  (interactive "<r>")
  (let ((comment-style 'multi-line))
    (comment-or-uncomment-region beg end)))

(defun +surround--line-range ()
  (save-excursion
    (back-to-indentation)
    (cons (point) (line-end-position))))

(defun +surround/gz ()
  "gz{motion} add, gzz{motion} add on new lines, gzd delete, gzr change."
  (interactive)
  (pcase (prog1 (read-key "gz-")
           ;; `read-key' clears `this-command-keys', from which evil derives the
           ;; operator's linewise shortcuts; an empty value breaks the motion read.
           (set--this-command-keys "gz"))
    (?d (call-interactively #'evil-surround-delete))
    (?r (call-interactively #'evil-surround-change))
    (?z (call-interactively #'evil-Surround-region))
    (key (push key unread-command-events)
         (call-interactively #'evil-surround-region))))

(defun +surround/gZ ()
  "gZ surround current line; gZZ on new lines; gZR change. Waits 400ms like nvim."
  (interactive)
  (let ((key (read-event nil nil 0.4))
        (range (+surround--line-range)))
    (pcase key
      (?Z (evil-Surround-region (car range) (cdr range) 'exclusive (evil-surround-read-char)))
      (?R (call-interactively #'evil-surround-change))
      (_ (when key (push key unread-command-events))
         (evil-surround-region (car range) (cdr range) 'exclusive (evil-surround-read-char))))))

;; Diagnostics display: quiet / focus / loud (plugins/lsp.lua cycle_diagnostic_mode)
(defvar +diagnostics-mode 'focus
  "quiet: fringe + underline. focus: popup at point. loud: end-of-line text.")

(defun +diagnostics--apply ()
  (let ((focus (eq +diagnostics-mode 'focus)))
    (setq flymake-show-diagnostics-at-end-of-line
          (and (eq +diagnostics-mode 'loud) 'short))
    (if focus
        (add-hook 'flymake-mode-hook #'flymake-popon-mode)
      (remove-hook 'flymake-mode-hook #'flymake-popon-mode))
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (when (bound-and-true-p flymake-mode)
          (when (fboundp 'flymake-popon-mode)
            (flymake-popon-mode (if focus 1 -1)))
          (flymake-start))))))

(defun +diagnostics/cycle ()
  "Cycle diagnostic display: quiet -> focus -> loud."
  (interactive)
  (setq +diagnostics-mode (pcase +diagnostics-mode
                            ('quiet 'focus) ('focus 'loud) (_ 'quiet)))
  (+diagnostics--apply)
  (message "Diagnostics: %s" +diagnostics-mode))

(defun +diagnostics/show-at-point ()
  "Show diagnostics on the current line (nvim vim.diagnostic.open_float)."
  (interactive)
  (if-let* ((diags (flymake-diagnostics (line-beginning-position) (line-end-position))))
      (message "%s" (mapconcat (lambda (d)
                                 (format "[%s] %s" (flymake-diagnostic-type d)
                                         (flymake-diagnostic-text d)))
                               diags "\n"))
    (message "No diagnostics on this line")))

(defun +diagnostics/next ()
  (interactive)
  (flymake-goto-next-error)
  (+diagnostics/show-at-point))

(defun +diagnostics/prev ()
  (interactive)
  (flymake-goto-prev-error)
  (+diagnostics/show-at-point))

(defun +format/toggle-on-save ()
  "Toggle format-on-save for this buffer (nvim b:disableFormatSave)."
  (interactive)
  (apheleia-mode 'toggle)
  (message "Format on save: %s" (if apheleia-mode "on" "off")))

(defun +lsp/docs-toggle ()
  "Toggle the eldoc documentation window (nvim docs-view)."
  (interactive)
  (if-let* ((buf (and (boundp 'eldoc--doc-buffer)
                      (buffer-live-p eldoc--doc-buffer)
                      eldoc--doc-buffer))
            (win (get-buffer-window buf)))
      (delete-window win)
    (call-interactively #'eldoc-doc-buffer)))

;; Run / REPL (run.nvim <leader>rr, iron.nvim <leader>r*)
(defun +run/file ()
  "Run the current file in a compilation buffer (run.nvim \"Run current file\")."
  (interactive)
  (let* ((file (or buffer-file-name (user-error "Buffer is not visiting a file")))
         (q (shell-quote-argument (file-local-name file)))
         (python (derived-mode-p 'python-base-mode))
         (root (and python
                    (executable-find "uv")
                    (locate-dominating-file file "pyproject.toml")))
         (cmd (cond
               (python
                (if root
                    (format "uv run --project %s python %s"
                            (shell-quote-argument (file-local-name (expand-file-name root))) q)
                  (format "python3 %s" q)))
               ((derived-mode-p 'julia-mode 'julia-ts-mode) (format "julia %s" q))
               ((derived-mode-p 'sh-mode 'bash-ts-mode)     (format "bash %s" q))
               ((derived-mode-p 'lua-mode 'lua-ts-mode)     (format "lua %s" q))
               ((derived-mode-p 'fish-mode)                 (format "fish %s" q)))))
    (save-buffer)
    (if cmd
        (let ((default-directory (file-name-directory file)))
          (compile cmd))
      (call-interactively #'compile))))

(defun +repl--buffer ()
  (or (and (fboundp '+eval-current-repl-buffer) (+eval-current-repl-buffer))
      (user-error "No REPL for this buffer (open one with SPC o r)")))

(defun +repl--send (string comint-fn)
  (let ((buf (+repl--buffer)))
    (with-current-buffer buf
      (if (derived-mode-p 'comint-mode)
          (funcall comint-fn)
        (process-send-string (get-buffer-process buf) string)))))

(defun +repl/clear ()     (interactive) (+repl--send "\C-l" #'comint-clear-buffer))
(defun +repl/interrupt () (interactive) (+repl--send "\C-c" #'comint-interrupt-subjob))
(defun +repl/newline ()   (interactive) (+repl--send "\n" #'comint-send-input))
(defun +repl/quit ()
  (interactive)
  (let ((kill-buffer-query-functions nil))
    (kill-buffer (+repl--buffer))))

;; Debugger (plugins/dap.lua)
(defun +dape/continue ()
  "Continue, or start a session when none is live (dap.continue)."
  (interactive)
  (if (and (fboundp 'dape--live-connection) (dape--live-connection 'last t))
      (call-interactively #'dape-continue)
    (call-interactively #'dape)))

(defhydra +dape-hydra (:color pink :hint nil)
  "
 Debug  _n_ over  _i_ into  _o_ out  _c_ continue  _C_ to cursor  _b_ breakpoint  _u_/_d_ stack up/down
        _K_ hover  _r_ repl  _U_ ui  _R_ restart  _X_ terminate  _q_ exit"
  ("n" dape-next)
  ("i" dape-step-in)
  ("o" dape-step-out)
  ("c" dape-continue)
  ("C" dape-until)
  ("b" dape-breakpoint-toggle)
  ("u" dape-stack-select-up)
  ("d" dape-stack-select-down)
  ("K" dape-evaluate-expression)
  ("r" dape-repl)
  ("U" dape-info)
  ("R" dape-restart)
  ("X" dape-quit :exit t)
  ("q" nil :exit t)
  ("<escape>" nil :exit t))

;; Enter the step hydra on the first stop of each session, like nvim's
;; event_initialized listener; leave it when the session is gone.
(defvar +dape--hydra-armed nil)
(defun +dape--arm-hydra-h (&rest _) (setq +dape--hydra-armed t))
(defun +dape--enter-hydra-h (&rest _)
  (when +dape--hydra-armed
    (setq +dape--hydra-armed nil)
    (+dape-hydra/body)))
(defun +dape--exit-hydra-h (&rest _)
  (when (and (boundp 'hydra-curr-map)
             (eq hydra-curr-map +dape-hydra/keymap)
             (not (dape--live-connection 'last t)))
    (hydra-keyboard-quit)))

(after! dape
  (add-hook 'dape-start-hook #'+dape--arm-hydra-h)
  (add-hook 'dape-stopped-hook #'+dape--enter-hydra-h)
  (add-hook 'dape-update-ui-hook #'+dape--exit-hydra-h))

;;; Windows ------------------------------------------------------------------

;; SPC w keeps plain window commands; copy the map before the C-w hydra heads
;; are bound into `evil-window-map' (nvim: only C-w<head> enters the hydra).
(defvar +window-leader-map (copy-keymap evil-window-map)
  "Keymap for SPC w: `evil-window-map' without hydra heads.")
(define-key +window-leader-map "o" #'delete-other-windows)

;; C-w hydra (config/keymaps.lua): C-w<head> runs the head, then heads repeat
;; without C-w; any other key exits and runs (red). Heads are bound directly
;; into `evil-window-map'; its other keys (u winner-undo, m maximize, ...) stay.
(defhydra +window-hydra (evil-window-map nil :color red :hint nil)
  "
 _h_ _j_ _k_ _l_ focus  _H_ _J_ _K_ _L_ resize  _C-h_ _C-j_ _C-k_ _C-l_ move far  _w_ next  _p_ prev  _x_ swap
 _r_ rotate  _n_ new  _=_ balance  _o_ only  _q_ close  _s_ _v_ split  _T_ tear off"
  ("h" evil-window-left)
  ("j" evil-window-down)
  ("k" evil-window-up)
  ("l" evil-window-right)
  ("H" +window/resize-left)
  ("J" +window/resize-down)
  ("K" +window/resize-up)
  ("L" +window/resize-right)
  ("C-h" +evil/window-move-left)
  ("C-j" +evil/window-move-down)
  ("C-k" +evil/window-move-up)
  ("C-l" +evil/window-move-right)
  ("w" other-window)
  ("C-w" other-window)
  ("p" evil-window-mru)
  ("x" evil-window-exchange)
  ("r" evil-window-rotate-downwards)
  ("n" evil-window-new)
  ("=" balance-windows)
  ("_" evil-window-set-height)
  ("|" evil-window-set-width)
  ("o" delete-other-windows)
  ("q" evil-window-delete)
  ("c" evil-window-delete)
  ;; Splits hand focus to the buffer picker (config.el advice), so they exit.
  ("s" evil-window-split :exit t)
  ("v" evil-window-vsplit :exit t)
  ("T" tear-off-window :exit t)
  ("<escape>" nil :exit t))

;;; Evil / global ------------------------------------------------------------

;; Doom's `gr' eval operator moves to SPC r c; `gr' becomes nvim 0.11's LSP prefix.
(map! :nv "gr" nil)

(map! :nv "s"   #'evil-avy-goto-char-2     ; hop HopChar2
      :nv "S"   #'evil-avy-goto-word-0     ; hop HopWord
      :n  "C-h" #'evil-window-left         ; smart-splits focus
      :n  "C-j" #'evil-window-down
      :n  "C-k" #'evil-window-up
      :n  "C-l" #'evil-window-right
      :n  "C-S-h" #'+window/resize-left    ; smart-splits resize
      :n  "C-S-j" #'+window/resize-down
      :n  "C-S-k" #'+window/resize-up
      :n  "C-S-l" #'+window/resize-right
      :n  "C-\\" #'evil-window-mru
      :n  "C-t" #'+ghostel/toggle          ; toggleterm
      ;; LuaSnip jumps (corfu's C-j/C-k win while its popup is open)
      :i  "C-j" #'yas-next-field-or-maybe-expand
      :i  "C-k" #'yas-prev-field
      ;; Comment.nvim block comments (gc/gcc are Doom's evil-nerd-commenter)
      :nv "gb"  #'+evil:comment-block
      ;; nvim-surround
      :n  "gz"  #'+surround/gz
      :n  "gZ"  #'+surround/gZ
      :v  "gz"  #'evil-surround-region
      :v  "gZ"  #'evil-Surround-region
      ;; nvim 0.11 default LSP maps (gd / K stay Doom's)
      :n  "grn" #'eglot-rename
      :nv "gra" #'eglot-code-actions
      :n  "grr" #'+lookup/references
      :n  "gri" #'+lookup/implementations
      :n  "grt" #'+lookup/type-definition
      :n  "gO"  #'consult-imenu)

(map! :after evil-surround
      :map evil-surround-mode-map
      :v "S" #'evil-avy-goto-word-0)

(map! :after ghostel
      :map ghostel-mode-map
      :nvie "C-t" #'+ghostel/toggle)

;;; Leader -------------------------------------------------------------------

;; Doom prefixes replaced by nvim ones, and keys that must stop being commands
;; before they become prefixes.
(map! :leader
      "c" nil                           ; code   -> SPC l
      "s" nil                           ; search -> SPC f
      "f l" nil)                        ; locate -> LSP pickers prefix

(map! :leader
      :desc "window" "w" +window-leader-map

      (:prefix "b"                   ; extends Doom's map, keeps its other keys
       :desc "Reload buffer"              "r" #'+buffer/revert-no-confirm
       :desc "Kill buffer without saving" "K" #'+buffer/kill-discard)

      (:prefix "f"                   ; extends Doom's map, keeps its other keys
       :desc "Find files"          "f" #'+vertico/consult-fd-or-find
       :desc "Live grep"           "g" #'+default/search-project
       :desc "Buffers"             "b" #'consult-buffer
       :desc "Help"                "h" #'describe-symbol
       :desc "Pickers"             "t" #'+consult/pickers
       :desc "Resume last search"  "r" #'vertico-repeat
       :desc "Symbols"             "s" #'consult-imenu
       :desc "Projects"            "p" #'projectile-switch-project
       :desc "File tree"           "n" #'dirvish-side
       :desc "File explorer"       "o" #'dired-jump
       (:prefix ("v" . "git")
        :desc "Git files"          "f" #'projectile-find-file
        :desc "Branches"           "b" #'magit-branch-checkout
        :desc "Status"             "s" #'magit-status
        :desc "Stash"              "x" #'magit-stash-list
        (:prefix ("c" . "commits")
         :desc "Commits"           "w" #'magit-log-current
         :desc "Buffer commits"    "b" #'magit-log-buffer-file))
       (:prefix ("l" . "lsp")
        (:prefix ("s" . "symbols")
         :desc "Document symbols"  "b" #'consult-imenu
         :desc "Workspace symbols" "w" #'consult-eglot-symbols)
        :desc "References"         "r" #'+lookup/references
        :desc "Implementations"    "i" #'+lookup/implementations
        :desc "Definitions"        "D" #'+lookup/definition
        :desc "Type definitions"   "t" #'+lookup/type-definition
        :desc "Diagnostics"        "d" #'consult-flymake))

      (:prefix "g"                   ; extends Doom's map, keeps its other keys
       :desc "Status"              "s" #'magit-status
       :desc "Commit"              "c" #'magit-commit-create
       :desc "Pull"                "p" #'magit-pull
       :desc "Push"                "P" #'magit-push
       :desc "Diff / resolve conflicts" "d" #'magit-ediff-dwim
       :desc "Diff working tree"   "D" #'magit-diff-working-tree)

      (:prefix ("l" . "lsp")
       (:prefix ("g" . "goto")
        :desc "Declaration"        "D" #'eglot-find-declaration
        :desc "Definition"         "d" #'+lookup/definition
        :desc "Type definition"    "t" #'+lookup/type-definition
        :desc "Implementations"    "i" #'+lookup/implementations
        :desc "References"         "r" #'+lookup/references
        :desc "Next diagnostic"    "n" #'+diagnostics/next
        :desc "Previous diagnostic" "p" #'+diagnostics/prev)
       (:prefix ("w" . "workspace")
        :desc "Workspace symbols"  "s" #'consult-eglot-symbols
        :desc "Workspace diagnostics" "d" #'flymake-show-project-diagnostics)
       (:prefix ("t" . "toggle")
        :desc "Format on save"     "f" #'+format/toggle-on-save
        :desc "Inlay hints"        "i" #'eglot-inlay-hints-mode
        :desc "Diagnostic display" "d" #'+diagnostics/cycle)
       (:prefix ("v" . "docs view")
        :desc "Toggle docs window" "t" #'+lsp/docs-toggle)
       :desc "Diagnostic at point" "e" #'+diagnostics/show-at-point
       :desc "Highlight symbol"   "H" #'highlight-symbol-at-point
       :desc "Document symbols"   "S" #'consult-imenu
       :desc "Document diagnostics" "d" #'flymake-show-buffer-diagnostics
       :desc "References"         "r" #'+lookup/references
       :desc "Hover"              "h" #'+lookup/documentation
       :desc "Signature help"     "s" #'eldoc
       :desc "Rename symbol"      "n" #'eglot-rename
       :desc "Code action"        "a" #'eglot-code-actions
       :desc "Format"             "f" #'+format/region-or-buffer)

      (:prefix "d"                   ; extends Doom's map, keeps its other keys
       :desc "Continue / start"   "c" #'+dape/continue
       :desc "Restart"            "R" #'dape-restart
       :desc "Terminate"          "q" #'dape-quit
       :desc "Start (RET reruns last)" "." #'dape
       :desc "Start"              "e" #'dape
       :desc "Toggle REPL"        "r" #'dape-repl
       :desc "Hover / evaluate"   "h" #'dape-evaluate-expression
       :desc "Toggle breakpoint"  "b" #'dape-breakpoint-toggle
       :desc "Toggle UI"          "u" #'dape-info
       :desc "Step mode (hydra)"  "s" #'+dape-hydra/body
       (:prefix ("g" . "go")
        :desc "Continue to cursor" "c" #'dape-until
        :desc "Step into"         "i" #'dape-step-in
        :desc "Step out"          "o" #'dape-step-out
        :desc "Next step"         "j" #'dape-next)
       (:prefix ("v" . "stack")
        :desc "Up stacktrace"     "o" #'dape-stack-select-up
        :desc "Down stacktrace"   "i" #'dape-stack-select-down))

      (:prefix ("r" . "run/repl")
       :desc "Run file"           "r"   #'+run/file
       :desc "Send motion/selection" "c" #'+eval:region
       :desc "Send file"          "f"   #'+eval/buffer
       :desc "Send line"          "l"   #'+eval/line-or-region
       :desc "Clear REPL"         "x"   #'+repl/clear
       :desc "Quit REPL"          "q"   #'+repl/quit
       :desc "Send RET"           "RET" #'+repl/newline
       :desc "Interrupt"          "SPC" #'+repl/interrupt))

;;; Localleader --------------------------------------------------------------

;; VimTeX-style `,l' group (plugins/tex.lua uses vimtex's defaults).
(map! :after latex
      :map LaTeX-mode-map
      :localleader
      (:prefix ("l" . "vimtex")
       :desc "Compile (latexmk)"  "l" #'TeX-command-run-all
       :desc "View / forward search" "v" #'TeX-view
       :desc "Next error"         "e" #'TeX-next-error
       :desc "Table of contents"  "t" #'reftex-toc
       :desc "Clean aux files"    "c" #'TeX-clean))
