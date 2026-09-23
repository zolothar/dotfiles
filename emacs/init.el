;;; init.el --- Personal Emacs configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Sections, in load order:
;;   1.  Interface basics
;;   2.  Fonts
;;   3.  Package management
;;   4.  Custom file
;;   5.  Editing defaults
;;   6.  Files and history
;;   7.  Completion
;;   8.  Theme and modeline
;;   9.  Org core
;;   10. Org capture and agenda
;;   11. Org reading and writing
;;   12. Org export and import
;;   13. Org babel
;;   14. Org roam
;;   15. Programming
;;   16. Treemacs
;;   17. Markdown

;;; Code:

;; --------------------------------------------------
;; 1. Interface basics
;; --------------------------------------------------

;; No startup screen
(setq inhibit-startup-message t)

;; Strip the GUI down to the text area
(scroll-bar-mode -1)
(tool-bar-mode -1)
(menu-bar-mode -1)
(tooltip-mode -1)

;; Space on the left and right edges, used for indicators
;; (line continuation, errors, etc.)
(set-fringe-mode 10)

;; Stay completely silent on errors: no sound, no flashing
(setq visible-bell nil
      ring-bell-function #'ignore)

;; ESC quits prompts
(global-set-key (kbd "<escape>") 'keyboard-escape-quit)

;; Line numbers in code buffers only, never in prose or Org
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'conf-mode-hook #'display-line-numbers-mode)
(setq display-line-numbers-width-start t)

;; Wrap long lines at the window edge instead of truncating
(global-visual-line-mode 1)

;; Smooth scrolling, current line highlight, matching parens
(pixel-scroll-precision-mode 1)
(global-hl-line-mode 1)
(show-paren-mode 1)

;; --------------------------------------------------
;; 2. Fonts
;; --------------------------------------------------

;; Height is in 1/10 pt, so 120 = 12pt.
;; This is the only absolute size; everything else is relative to it.
(set-face-attribute 'default nil :family "JetBrains Mono" :height 120)

;; `fixed-pitch' is used wherever alignment matters: code blocks,
;; tables, verbatim text. `variable-pitch' is used for prose.
;; Height 1.0 means "same as default", so both scale together.
(set-face-attribute 'fixed-pitch nil :family "JetBrains Mono" :height 1.0)
(set-face-attribute 'variable-pitch nil :family "Inter" :height 1.0)

;; --------------------------------------------------
;; 3. Package management
;; --------------------------------------------------

(require 'package)

;; MELPA - large community repository with frequent updates
;; ELPA  - official GNU repository
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("elpa"  . "https://elpa.gnu.org/packages/")))

;; Initialize installed packages and update load-path
(package-initialize)

;; Refresh the archive index only when it is missing entirely.
;; Deliberate: this machine is often offline, and an unconditional
;; refresh makes startup hang waiting on the network.
;; When a package fails to install with "Not found", the local index is
;; stale - run M-x package-refresh-contents by hand, then retry.
(unless package-archive-contents
  (package-refresh-contents))

;; Bootstrap use-package
(unless (package-installed-p 'use-package)
  (package-install 'use-package))
(require 'use-package)

;; Install declared packages automatically
(setq use-package-always-ensure t)

;; --------------------------------------------------
;; 4. Custom file
;; --------------------------------------------------

;; Keep the Customize interface from writing into this file.
;; Anything set through M-x customize lands in custom.el instead.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;; --------------------------------------------------
;; 5. Editing defaults
;; --------------------------------------------------

;; Spaces, never tabs. `setq-default' is required here: indent-tabs-mode
;; is buffer-local, so a plain setq would only affect the current buffer.
(setq-default indent-tabs-mode nil)

;; Jump to any window by letter instead of cycling with C-x o
(use-package ace-window
  :bind ("M-o" . ace-window))

;; Visual undo history as a tree
(use-package vundo
  :bind ("C-x u" . vundo))

;; Spell checking. Requires: aspell aspell-ru aspell-en
;; C-c d switches the dictionary between "ru" and "en".
(setq ispell-program-name "aspell"
      ispell-dictionary "ru"
      flyspell-issue-message-flag nil)

(global-set-key (kbd "C-c d") #'ispell-change-dictionary)

(add-hook 'text-mode-hook #'flyspell-mode)

;; --------------------------------------------------
;; 6. Files and history
;; --------------------------------------------------

;; Remember minibuffer history, recent files and cursor position
(savehist-mode 1)
(recentf-mode 1)
(save-place-mode 1)

;; The file itself is the only copy: no file~ backups, no #file#
;; auto-saves.
(setq make-backup-files nil
      auto-save-default nil
      create-lockfiles nil)

;; Save on a 5-second idle pause
(setq auto-save-visited-interval 5)
(auto-save-visited-mode 1)

;; Save when moving to another window or buffer
(add-hook 'window-selection-change-functions
          (lambda (_) (save-some-buffers t)))

;; Save when Emacs loses focus
(add-function :after after-focus-change-function
              (lambda ()
                (unless (frame-focus-state)
                  (save-some-buffers t))))

;; --------------------------------------------------
;; 7. Completion
;; --------------------------------------------------

;; Vertical candidate list in the minibuffer
(use-package vertico
  :init (vertico-mode))

;; Match space-separated fragments in any order: "pel cam" finds
;; pelletizing-cameras.org
(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

;; Annotations next to candidates
(use-package marginalia
  :init (marginalia-mode))

;; Search commands built on top of completion
(use-package consult
  :bind (("C-x b" . consult-buffer)
         ("C-s"   . consult-line)
         ("M-y"   . consult-yank-pop)
         ("C-c s" . consult-ripgrep)          ; needs ripgrep installed
         ("C-c o" . consult-org-heading)))    ; jump between Org headings

;; Popup showing available key bindings after a prefix
(use-package which-key
  :init (which-key-mode))

;; In-buffer completion popup. Declared after `orderless' so that it
;; picks up the completion styles set above.
(use-package corfu
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.2)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  :init (global-corfu-mode))

;; Extra completion sources: file paths and words from open buffers
(use-package cape
  :init
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-dabbrev))

(use-package nerd-icons-corfu
  :after corfu
  :config
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))

;; --------------------------------------------------
;; 8. Theme and modeline
;; --------------------------------------------------

(use-package nerd-icons)

(use-package kanagawa-themes
  :config (load-theme 'kanagawa-wave t))

;; Internal padding around windows, mode line and dividers
(use-package spacious-padding
  :config (spacious-padding-mode 1))

(use-package doom-modeline
  :init (doom-modeline-mode 1)
  :custom (doom-modeline-height 30))

;; --------------------------------------------------
;; 9. Org core
;; --------------------------------------------------

;; Hide the markup characters around *bold* and /italic/
(setq org-hide-emphasis-markers t)

;; Inline images
(setq org-startup-with-inline-images t
      org-image-actual-width nil
      org-image-max-width 600)

;; Agenda picks up every .org file under ~/org, including new ones
(setq org-agenda-files (directory-files-recursively "~/org" "\\.org$"))

;; --------------------------------------------------
;; 10. Org capture and agenda
;; --------------------------------------------------

(setq org-default-notes-file "~/org/inbox.org")

;; %a inserts a link back to wherever capture was invoked from:
;; a line of code, an Org heading, a mail message.
(setq org-capture-templates
      '(("t" "Task" entry
         (file "~/org/inbox.org")
         "* TODO %?\n  %U\n  %a" :empty-lines 1)

        ("n" "Note" entry
         (file "~/org/inbox.org")
         "* %?\n  %U" :empty-lines 1)

        ("j" "Journal" entry
         (file+olp+datetree "~/org/journal.org")
         "* %<%H:%M> %?" :empty-lines 1)

        ("l" "Link with note" entry
         (file "~/org/inbox.org")
         "* %?\n  %U\n  %i\n  %a" :empty-lines 1)))

(global-set-key (kbd "C-c c") #'org-capture)
(global-set-key (kbd "C-c a") #'org-agenda)

;; TODO states with a waiting stage. Letters in parentheses are quick
;; selectors; @ prompts for a note, ! records a timestamp.
(setq org-todo-keywords
      '((sequence "TODO(t)" "NEXT(n)" "WAIT(w@/!)"
                  "|" "DONE(d!)" "CANCELLED(c@)"))
      org-log-done 'time
      org-log-into-drawer t)

;; C-c C-w moves a heading to any file in the agenda, with completion
(setq org-refile-targets '((org-agenda-files :maxlevel . 3))
      org-refile-use-outline-path 'file
      org-outline-path-complete-in-steps nil)

;; --------------------------------------------------
;; 11. Org reading and writing
;; --------------------------------------------------

;; Center the text column instead of letting it span the whole window
(defun my/org-reading-setup ()
  "Center Org text in a fixed-width column."
  (setq visual-fill-column-width 120
        visual-fill-column-center-text t)
  (visual-fill-column-mode 1))

(use-package visual-fill-column
  :hook (org-mode . my/org-reading-setup))

;; Reveal hidden markup only while the cursor is inside it
(use-package org-appear
  :hook (org-mode . org-appear-mode))

;; Proportional font for prose, monospace where alignment matters
(use-package mixed-pitch
  :hook (org-mode . mixed-pitch-mode))

;; Screenshots and clipboard images straight into a note.
;; Requires scrot and xclip on X11; on Wayland use grim + slurp and set
;; org-download-screenshot-method to "grim -g \"$(slurp)\" %s"
(use-package org-download
  :after org
  :bind (:map org-mode-map
              ("C-c i s" . org-download-screenshot)
              ("C-c i y" . org-download-yank))
  :config
  (setq org-download-method 'directory
        org-download-image-dir "./images"
        org-download-heading-lvl nil
        org-download-screenshot-method "scrot -s %s"))

;; --------------------------------------------------
;; 12. Org export and import
;; --------------------------------------------------

;; Markdown import. Not on MELPA, installed straight from git.
(unless (package-installed-p 'org-pandoc-import)
  (package-vc-install "https://github.com/tecosaur/org-pandoc-import"))

(use-package org-pandoc-import
  :ensure nil                                  ; installed via package-vc
  :after org
  :bind (("C-c n m" . org-pandoc-import-to-org)))

;; Export to docx, odt, epub and everything else pandoc handles
(use-package ox-pandoc
  :after org)

;; Built-in Markdown export backend, C-c C-e m m
(with-eval-after-load 'org
  (require 'ox-md))

;; --------------------------------------------------
;; 13. Org babel
;; --------------------------------------------------

(setq org-plantuml-jar-path (expand-file-name "~/packages/jar/plantuml.jar"))

;; One call only: org-babel-do-load-languages replaces the language
;; list rather than adding to it, so separate calls cancel each other.
;; Section 13, add to the language list
(org-babel-do-load-languages
 'org-babel-load-languages
 '((python   . t)
   (plantuml . t)
   (sql      . t)
   (shell    . t)))

(setq org-babel-python-command "python3")

;; Let the language mode handle indentation inside source blocks
(setq org-edit-src-content-indentation 0
      org-src-preserve-indentation nil)

;; Evaluate blocks without asking every time
(setq org-confirm-babel-evaluate nil)

;; --------------------------------------------------
;; 14. Org roam
;; --------------------------------------------------

(use-package org-roam
  :custom
  (org-roam-directory "~/notes")
  (org-roam-completion-everywhere t)
  (org-roam-capture-templates
   '(("d" "default" plain
      "%?"
      :if-new (file+head "${title}.org" "#+title: ${title}\n")
      :unnarrowed t)))
  :bind (("C-c n l" . org-roam-buffer-toggle)
         ("C-c n f" . org-roam-node-find)
         ("C-c n i" . org-roam-node-insert)
         ("C-c n c" . org-roam-capture)
         :map org-mode-map
         ("C-M-i" . completion-at-point))
  :config
  (org-roam-setup))

;; --------------------------------------------------
;; 15. Programming
;; --------------------------------------------------

;; Tree-sitter grammar sources. Versions are pinned to tags built
;; against ABI 14, which is what Emacs 29 on Ubuntu 24.04 supports.
;; Install with M-x treesit-install-language-grammar
(setq treesit-language-source-alist
      '((python     . ("https://github.com/tree-sitter/tree-sitter-python" "v0.21.0"))
        (bash       . ("https://github.com/tree-sitter/tree-sitter-bash" "v0.21.0"))
        (json       . ("https://github.com/tree-sitter/tree-sitter-json" "v0.21.0"))
        (yaml       . ("https://github.com/ikatyang/tree-sitter-yaml" "v0.5.0"))
        (toml       . ("https://github.com/tree-sitter/tree-sitter-toml" "v0.5.1"))
        (dockerfile . ("https://github.com/camdencheek/tree-sitter-dockerfile" "v0.2.0"))
        (sql        . ("https://github.com/DerekStride/tree-sitter-sql" "gh-pages"))))

;; Use tree-sitter modes, but only where the grammar actually loaded.
;; A missing grammar would otherwise leave the buffer in a broken mode.
(dolist (pair '((python-mode . (python-ts-mode . python))
                (sh-mode     . (bash-ts-mode   . bash))
                (js-mode     . (js-ts-mode     . javascript))
                (json-mode   . (json-ts-mode   . json))
                (yaml-mode   . (yaml-ts-mode   . yaml))))
  (let ((from (car pair))
        (to   (cadr pair))
        (lang (cddr pair)))
    (when (treesit-language-available-p lang)
      (add-to-list 'major-mode-remap-alist (cons from to)))))

;; Make ~/.local/bin visible to Emacs (pipx, user tools)
(let ((local-bin (expand-file-name "~/.local/bin")))
  (when (file-directory-p local-bin)
    (add-to-list 'exec-path local-bin)
    (setenv "PATH" (concat local-bin ":" (getenv "PATH")))))

(use-package magit
  :bind ("C-x g" . magit-status))

;; Show added, changed and removed lines in the fringe
(use-package diff-hl
  :hook ((prog-mode . diff-hl-mode)
         (org-mode  . diff-hl-mode)
         (dired-mode . diff-hl-dired-mode)
         (magit-pre-refresh  . diff-hl-magit-pre-refresh)
         (magit-post-refresh . diff-hl-magit-post-refresh))
  :config
  (diff-hl-flydiff-mode))              ; update as you type, not only on save

;; Make stray trailing whitespace visible in code, but not in prose
(add-hook 'prog-mode-hook
          (lambda () (setq show-trailing-whitespace t)))

;; --- Python ---------------------------------------
;; python-ts-mode is NOT derived from python-mode. Both inherit from
;; python-base-mode, so every Python hook below uses that parent.

(defun my-python-mode-hook ()
  "Custom settings for Python buffers."
  (setq indent-tabs-mode nil
        tab-width 4
        python-indent-offset 4))

(add-hook 'python-base-mode-hook #'my-python-mode-hook)

(use-package eglot
  :ensure nil                                  ; built into Emacs 29+
  :hook (python-base-mode . eglot-ensure))

;; Auto-activate the virtualenv found next to the project
(use-package pet
  :config
  (add-hook 'python-base-mode-hook #'pet-mode -10))

;; Fast linting via ruff
(use-package flymake-ruff
  :hook (eglot-managed-mode . flymake-ruff-load))

(use-package reformatter
  :config
  (reformatter-define ruff-format
    :program "ruff"
    :args (list "format" "--stdin-filename" (buffer-file-name) "-")))

;; Format on save
(add-hook 'python-base-mode-hook #'ruff-format-on-save-mode)

;; --- Terminal -------------------------------------

(use-package vterm
  :custom
  (vterm-max-scrollback 10000)
  (vterm-kill-buffer-on-exit t)
  :bind (("C-c t" . my/vterm-project)
         :map vterm-mode-map
         ("C-c t" . delete-window)))     ; same key hides it again

(defun my/vterm-project ()
  "Open vterm in the project root, or in default-directory outside a project."
  (interactive)
  (let ((default-directory (or (when-let ((proj (project-current)))
                                 (project-root proj))
                               default-directory)))
    (vterm)))

;; Terminal and compilation output live in a bottom side window
(add-to-list 'display-buffer-alist
             '("\\*\\(vterm\\|compilation\\)\\*"
               (display-buffer-reuse-window display-buffer-in-side-window)
               (side . bottom)
               (slot . 0)
               (window-height . 0.3)
               (dedicated . t)))

;; --------------------------------------------------
;; 16. Treemacs
;; --------------------------------------------------

;; Roots shown in the sidebar. Added once, then stored in
;; ~/.emacs.d/treemacs-persist across sessions.
(defvar my/treemacs-roots '("~/org" "~/notes")
  "Directories pinned to the Treemacs workspace.")

(defun my/treemacs-pin-roots ()
  "Add `my/treemacs-roots' to the workspace if not already there."
  (dolist (dir my/treemacs-roots)
    (let ((path (expand-file-name dir)))
      (when (and (file-directory-p path)
                 (not (treemacs-is-path path :in-workspace)))
        (treemacs-do-add-project-to-workspace
         path (file-name-nondirectory (directory-file-name path)))))))

(defun my/treemacs-start ()
  "Open Treemacs without moving point out of the current window."
  (let ((win (selected-window)))
    (treemacs)
    (my/treemacs-pin-roots)
    (select-window win)))

(use-package treemacs
  :bind (("C-x t t" . treemacs)                ; show / hide
         ("M-0"     . treemacs-select-window)  ; jump to the sidebar
         ("C-x t f" . treemacs-find-file)      ; locate current file in tree
         ("C-x t d" . treemacs-select-directory)
         ("C-x t 1" . treemacs-delete-other-windows))
  :config
  (setq treemacs-width                     32
        treemacs-width-is-initially-locked nil
        treemacs-is-never-other-window     t
        treemacs-indentation               2
        treemacs-collapse-dirs             3
        treemacs-sorting                   'alphabetic-case-insensitive-asc
        treemacs-show-hidden-files         t
        treemacs-silent-refresh            t
        treemacs-silent-filewatch          t
        treemacs-file-event-delay          1000
        treemacs-text-scale                -1
        ;; Do not chase the current buffer. The tree stays where it is,
        ;; the way the Obsidian file pane does.
        treemacs-follow-after-init         nil)

  (treemacs-filewatch-mode t)                  ; pick up on-disk changes
  (treemacs-git-mode 'deferred)                ; git status, async
  (treemacs-indent-guide-mode t)
  (treemacs-fringe-indicator-mode 'always)

  (add-hook 'emacs-startup-hook #'my/treemacs-start))

;; Icons from nerd-icons
(use-package treemacs-nerd-icons
  :after (treemacs nerd-icons)
  :config (treemacs-load-theme "nerd-icons"))

;; Refresh the tree after magit operations
(use-package treemacs-magit
  :after (treemacs magit))

;; --------------------------------------------------
;; 17. Markdown
;; --------------------------------------------------

(use-package markdown-mode
  :mode ("\\.md\\'" . markdown-mode))

;;; init.el ends here
