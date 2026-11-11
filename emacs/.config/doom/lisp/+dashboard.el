;;; lisp/+dashboard.el -*- lexical-binding: t; -*-
;;
;; Doom dashboard mirroring the nvim one (neovim/.config/nvim/lua/plugins/dashboard.lua):
;; figlet banner, seven single-key entries, no footer, no mode-line.
;;
;; banner.txt was generated, not drawn:
;;   uvx --from pyfiglet pyfiglet -w 200 -f delta_corps_priest_1 EMACS
;; ("Delta Corps Priest 1": same font as the nvim NEOVIM header; Omarchy's logo
;; is a narrowed variant of it.)

(defvar +dashboard-emacs-banner (expand-file-name "banner.txt" doom-user-dir)
  "Text file holding the dashboard's ASCII banner.")

(defface +dashboard-icon '((t (:inherit success)))
  "Face for dashboard menu icons."
  :group '+dashboard)

(defun +dashboard-emacs-banner-fn ()
  "Return the EMACS figlet banner from `+dashboard-emacs-banner'."
  (when (file-readable-p +dashboard-emacs-banner)
    (propertize (with-temp-buffer
                  (insert-file-contents +dashboard-emacs-banner)
                  (string-trim-right (buffer-string)))
                'face '+dashboard-banner)))

(defun +dashboard--icon (codepoint)
  (propertize (string codepoint) 'face '+dashboard-icon))

;; Text banner in GUI frames too (no Doom PNG).
(setq fancy-splash-image nil
      +dashboard-ascii-banner-fn #'+dashboard-emacs-banner-fn
      +dashboard-banner-vertical-padding '(2 . 3)
      +dashboard-functions '(+dashboard-widget-banner
                             +dashboard-widget-shortmenu))

;; Same entries, keys and glyphs as nvim (glyphs by codepoint, from dashboard.lua).
(setq +dashboard-menu-sections
      `(("Recently opened files" :icon (+dashboard--icon #xF1DA)  :key "r" :action consult-recent-file)
        ("Open project"          :icon (+dashboard--icon #xE5FB)  :key "p" :action projectile-switch-project)
        ("Open file explorer"    :icon (+dashboard--icon #xE5FF)  :key "o" :action dirvish)
        ("Magit"                 :icon (+dashboard--icon #xF02A2) :key "s" :action magit-status)
        ("Grep"                  :icon (+dashboard--icon #xF002)  :key "g" :action +default/search-project)
        ("Find file"             :icon (+dashboard--icon #xF021E) :key "f" :action +vertico/consult-fd-or-find)
        ("New file"              :icon (+dashboard--icon #xF15B)  :key "e" :action evil-buffer-new)))

(map! :map +dashboard-mode-map
      :n "r" #'consult-recent-file
      :n "p" #'projectile-switch-project
      :n "o" #'dirvish
      :n "s" #'magit-status
      :n "g" #'+default/search-project
      :n "f" #'+vertico/consult-fd-or-find
      :n "e" #'evil-buffer-new)

;; nvim hides the statusline on the dashboard.
(add-hook '+dashboard-mode-hook #'mode-line-invisible-mode)

;; nvim colors by role (banner blue, icons green, keys purple, text fg); taken
;; from the active doom theme, falling back to nvim's oxocarbon values.
(defun +dashboard--color (name fallback)
  (or (and (fboundp 'doom-color) (ignore-errors (doom-color name))) fallback))

(custom-set-faces!
  `(+dashboard-banner     :foreground ,(+dashboard--color 'blue "#4589ff") :weight normal)
  `(+dashboard-icon       :foreground ,(+dashboard--color 'green "#42be65"))
  `(+dashboard-menu-title :foreground ,(+dashboard--color 'fg "#f2f4f8"))
  `(+dashboard-menu-desc  :foreground ,(+dashboard--color 'magenta "#be95ff")))
