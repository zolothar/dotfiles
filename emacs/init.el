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

;; --- Vocabulary -----------------------------------
;; Extend either list and everything below follows: capture prompts,
;; agenda groups, timeblock colours.

(defvar my/org-areas
  '("routine" "home" "work" "coding" "road" "workouts" "fun" "system")
  "Areas of life. Used as Org CATEGORY and as a tag.")

(defvar my/org-types
  '("project" "knowledge" "calendar")
  "Document types.")

;; Type to its subdirectory. Plural for projects, singular elsewhere.
(defvar my/org-type-dirs
  '(("project"   . "projects")
    ("knowledge" . "knowledge")
    ("calendar"  . "calendar"))
  "Map a document type to its subdirectory under `my/org-dir'.")

;; These are split one level further, by area.
;; Below that:
;;   projects/<area>/<name>/<name>.org   + <name>/attachments/
;;   knowledge/<area>/<topic>/<name>.org + <topic>/attachments/
;; so a project owns its folder, while knowledge notes share one
;; attachments folder per topic (coding/python, work/pcs7, ...).
(defvar my/org-area-split-dirs '("projects" "knowledge")
  "Type directories that get an area subdirectory.")

(defvar my/org-dir (expand-file-name "~/org")
  "Root of all Org content.")

(dolist (dir (append (mapcar #'cdr my/org-type-dirs)
                     '("archive" "templates")))
  (make-directory (expand-file-name dir my/org-dir) t))

(dolist (dir my/org-area-split-dirs)
  (dolist (area my/org-areas)
    (make-directory (expand-file-name (concat dir "/" area) my/org-dir) t)))

;; --- Tags and properties --------------------------

;; Types are mutually exclusive, areas are not enforced but listed
;; for completion. C-c C-q on a heading opens the selector.
(setq org-tag-alist
      `((:startgroup)
        ("project"   . ?p)
        ("research"  . ?r)
        ("knowledge" . ?k)
        ("calendar"  . ?C)
        (:endgroup)
        (:newline)
        ,@(mapcar (lambda (a) (cons a nil)) my/org-areas)
        (:newline)
        ("someday" . ?s)
        ("urgent"  . ?u)))

;; Allowed values offered by C-c C-x p (org-set-property)
(setq org-global-properties
      `(("TYPE_ALL"   . ,(mapconcat #'identity my/org-types " "))
        ("AREA_ALL"   . ,(mapconcat #'identity my/org-areas " "))
        ("STATUS_ALL" . "idea active paused done archived")))

;; Speed commands: on a heading, single letters act as commands.
;; n/p move, u goes up, t cycles TODO, i inserts a heading, ? lists all.
(setq org-use-speed-commands t)

;; --------------------------------------------------
;; 10. Org capture, agenda and calendar
;; --------------------------------------------------

;; --- Which files the agenda scans -----------------
;; Only tasks and calendar blocks. Knowledge and research files hold no
;; scheduled items, so scanning them would only slow the agenda down.
;; org-roam still indexes everything (section 14).

(defun my/org-agenda-files ()
  "Rebuild the agenda file list from disk."
  (append (list (expand-file-name "inbox.org" my/org-dir))
          (directory-files-recursively
           (expand-file-name "projects" my/org-dir) "\\.org$")
          (directory-files-recursively
           (expand-file-name "calendar" my/org-dir) "\\.org$")))

(setq org-agenda-files (my/org-agenda-files))

(defun my/org-agenda-refresh-files ()
  "Pick up newly created project or calendar files."
  (interactive)
  (setq org-agenda-files (my/org-agenda-files))
  (message "Agenda files: %d" (length org-agenda-files)))

;; --- Capture --------------------------------------

(setq org-default-notes-file (expand-file-name "inbox.org" my/org-dir))

;; %a inserts a link back to wherever capture was invoked from.
;; %^{Area|...} offers completion; asking twice with the same prompt
;; name reuses the first answer.
(setq org-capture-templates
      '(("t" "Task to inbox" entry
         (file "~/org/inbox.org")
         "* TODO %?\n  %U\n  %a" :empty-lines 1)

        ("s" "Scheduled task" entry
         (file "~/org/inbox.org")
         "* TODO %? :%^{Area|work|coding|home|system|workouts|fun|routine|road}:\n  SCHEDULED: %^{When}T\n  %U"
         :empty-lines 1)

        ("n" "Note to inbox" entry
         (file "~/org/inbox.org")
         "* %?\n  %U" :empty-lines 1)

        ("l" "Link with note" entry
         (file "~/org/inbox.org")
         "* %?\n  %U\n  %i\n  %a" :empty-lines 1)

        ("j" "Journal" entry
         (file+olp+datetree "~/org/journal.org")
         "* %<%H:%M> %?" :empty-lines 1)

        ("e" "Calendar event" entry
         (file+headline "~/org/calendar/events.org" "Events")
         "* %^{Title} :%^{Area|work|coding|home|system|workouts|fun|routine|road}:\n  %^{When}T"
         :empty-lines 1)))

(global-set-key (kbd "C-c c") #'org-capture)
(global-set-key (kbd "C-c a") #'org-agenda)

;; --- TODO states ----------------------------------

(setq org-todo-keywords
      '((sequence "TODO(t)" "NEXT(n)" "WAIT(w)"
                  "|" "DONE(d)" "CANCELLED(c)"))
      org-log-done nil
      org-log-into-drawer nil)

;; C-c C-w moves a heading to any file in the agenda, with completion
(setq org-refile-targets '((org-agenda-files :maxlevel . 3))
      org-refile-use-outline-path 'file
      org-outline-path-complete-in-steps nil)

;; --- Agenda appearance ----------------------------

;; Show the area (category) as the leftmost column
(setq org-agenda-prefix-format
      '((agenda . " %i %-10c%?-12t% s")
        (todo   . " %i %-10c")
        (tags   . " %i %-10c")
        (search . " %i %-10c")))

;; Full-day time grid, one line per hour.
;; No `require-timed': grid lines are drawn even for empty hours.
;; Narrow the range to waking hours if 24 lines is too much, e.g.
;; (number-sequence 600 2300 100)
(setq org-agenda-time-grid
      `((daily today)
        ,(number-sequence 0 2300 100)
        "      " "────────────────")
      org-agenda-current-time-string "──────────────── now"
      org-agenda-show-current-time-in-grid t)

(setq org-agenda-span 'day
      org-agenda-start-on-weekday nil
      org-agenda-skip-scheduled-if-done t
      org-agenda-skip-deadline-if-done t
      org-agenda-window-setup 'current-window
      org-agenda-restore-windows-after-quit t)

;; --- Grouping -------------------------------------

(use-package org-super-agenda
  :after org-agenda
  :config
  (setq org-super-agenda-groups
        '((:name "Now"        :time-grid t         :order 1)
          (:name "Overdue"    :deadline past       :order 2)
          (:name "Due today"  :deadline today      :order 3)
          (:name "Work"       :category "work"     :order 10)
          (:name "Coding"     :category "coding"   :order 11)
          (:name "System"     :category "system"   :order 12)
          (:name "Home"       :category "home"     :order 13)
          (:name "Workouts"   :category "workouts" :order 14)
          (:name "Fun"        :category "fun"      :order 15)
          (:name "Road"       :category "road"     :order 20)
          (:name "Routine"    :category "routine"  :order 21)
          (:name "Inbox"      :file-path "inbox"   :order 30)))
  (org-super-agenda-mode))

;; --- Custom views ---------------------------------

(setq org-agenda-custom-commands
      '(("d" "Day"
         ((agenda "" ((org-agenda-span 'day)))))

        ("W" "Week"
         ((agenda "" ((org-agenda-span 7)
                      (org-agenda-use-time-grid nil)))))

        ("w" "Work day"
         ((agenda "" ((org-agenda-span 'day)))
          (tags-todo "project"
                     ((org-agenda-overriding-header "Work projects"))))
         ((org-agenda-category-filter-preset '("+work"))))

        ("c" "Coding day"
         ((agenda "" ((org-agenda-span 'day)))
          (tags-todo "project|knowledge"
                     ((org-agenda-overriding-header "Coding"))))
         ((org-agenda-category-filter-preset '("+coding"))))

        ("i" "Inbox to process" tags-todo "*"
         ((org-agenda-files (list (expand-file-name "inbox.org" my/org-dir)))
          (org-agenda-overriding-header "Inbox")))

        ("P" "Active projects" tags "project+STATUS=\"active\""
         ((org-agenda-overriding-header "Active projects")))

        ("N" "Next actions" todo "NEXT"
         ((org-agenda-overriding-header "Next")))))

;; --- Visual timeblocking --------------------------

(use-package org-timeblock
  :bind ("C-c b" . org-timeblock)
  :config
  ;; Colours keyed by area tag. Routine is deliberately dim: it is
  ;; background, not work.
  (setq org-timeblock-tag-colors
        '(("routine"  . (:background "#2a2a37" :foreground "#727169"))
          ("road"     . (:background "#2a2a37" :foreground "#727169"))
          ("work"     . (:background "#2d4f67" :foreground "#c8c093"))
          ("coding"   . (:background "#43242b" :foreground "#c8c093"))
          ("system"   . (:background "#49443c" :foreground "#c8c093"))
          ("home"     . (:background "#223249" :foreground "#c8c093"))
          ("workouts" . (:background "#2b3328" :foreground "#c8c093"))
          ("fun"      . (:background "#54536d" :foreground "#c8c093")))))

;; --- Queries (the Dataview replacement) -----------

(use-package org-ql
  :bind ("C-c q" . org-ql-search))

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
  ;; Screenshots go through org-attach, so they land in the note's own
  ;; attachments folder and survive the note being moved.
  (setq org-download-method 'attach
        org-download-heading-lvl nil
        org-download-screenshot-method "scrot -s %s"))

;; --- Attachments ----------------------------------
;; Storage location comes from the :DIR: property set by the capture
;; templates, not from an ID-keyed store: every note keeps its files
;; in a plain attachments/ folder next to it.

(use-package org-attach
  :ensure nil                          ; built into Org
  :after org
  :custom
  (org-attach-method 'cp)              ; copy, leave the original alone
  (org-attach-store-link-p 'attached)
  (org-attach-use-inheritance t)       ; a task sees its file's DIR
  ;; Without a DIR, fall back to a named folder rather than data/<id>/
  (org-attach-preferred-new-method 'dir)
  (org-attach-dir-relative t)          ; store DIR as a relative path
  (org-attach-archive-delete 'query))

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

;; --- Web clipping ---------------------------------
;; Browsers put both text/plain and text/html on the clipboard. Emacs
;; yanks the plain flavour, which is why formatting is lost. These
;; commands take the HTML flavour and run it through pandoc.

(defvar my/clipboard-html-command
  (cond ((executable-find "wl-paste") "wl-paste --no-newline --type text/html")
        ((executable-find "xclip")    "xclip -selection clipboard -t text/html -o")
        ((executable-find "pbpaste")  "osascript -e 'the clipboard as \"HTML\"'"))
  "Shell command returning the clipboard's text/html flavour, if any.")

(defun my/clipboard-html ()
  "Return the clipboard as HTML, or nil when it holds no HTML."
  (when my/clipboard-html-command
    (let ((s (shell-command-to-string
              (concat my/clipboard-html-command " 2>/dev/null"))))
      (unless (string-blank-p s) s))))

(defun my/org-paste-html ()
  "Paste the clipboard as Org markup, converting from HTML via pandoc.
Falls back to a plain yank when the clipboard carries no HTML."
  (interactive)
  (let ((html (my/clipboard-html)))
    (if (not html)
        (yank)
      (insert
       (with-temp-buffer
         (insert html)
         (shell-command-on-region
          (point-min) (point-max)
          "pandoc -f html -t org --wrap=preserve"
          nil t "*pandoc errors*")
         (buffer-string))))))

;; Render remote images inline. Org only displays local files on its
;; own; this caches HTTP images so pasted articles show their pictures.
(unless (package-installed-p 'org-remoteimg)
  (package-vc-install "https://github.com/gaoDean/org-remoteimg"))

(use-package org-remoteimg
  :ensure nil                                  ; installed via package-vc
  :after org
  :custom (org-display-remote-inline-images 'cache))

(defun my/org-localize-images ()
  "Download every remote image in the buffer into the note's attachments
and rewrite its link to point at the local copy."
  (interactive)
  (require 'org-download)
  (save-excursion
    (goto-char (point-min))
    (let ((count 0)
          (rx "\\[\\[\\(https?://[^]]+?\\.\\(?:png\\|jpe?g\\|gif\\|webp\\|svg\\)\\)\\]\\]"))
      (while (re-search-forward rx nil t)
        (let ((url (match-string 1)))
          (replace-match "")
          (org-download-image url)
          (setq count (1+ count))))
      (message "Localized %d image(s)" count))))

;; Fetch a whole page, strip the navigation and ads, insert as a subtree
(use-package org-web-tools
  :after org
  :bind (("C-c n u" . org-web-tools-insert-web-page-as-entry)
         ("C-c n U" . org-web-tools-insert-link-for-url)))

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c v") #'my/org-paste-html)
  (define-key org-mode-map (kbd "C-c V") #'my/org-localize-images))

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
  ;; Every Org file under ~/org is a potential node
  (org-roam-directory my/org-dir)
  (org-roam-completion-everywhere t)
  ;; Skip generated and archived material
  (org-roam-file-exclude-regexp
   '("/archive/" "/templates/" "/attachments/" "/\\.git/"))
  :bind (("C-c n f" . org-roam-node-find)
         ("C-c n i" . org-roam-node-insert)
         ("C-c n c" . org-roam-capture)
         ("C-c n l" . org-roam-buffer-toggle)
         ("C-c n g" . org-roam-graph)
         ("C-c n e" . org-roam-extract-subtree)
         ("C-c n s" . org-roam-db-sync)
         :map org-mode-map
         ("C-M-i" . completion-at-point))
  :config
  ;; Show the subdirectory (that is, the type) and tags in the selector
  (cl-defmethod org-roam-node-type ((node org-roam-node))
    "Return the first two path components of NODE under `org-roam-directory'.
That is \"projects/work\" or \"knowledge/coding\", not the whole path."
    (let* ((rel (file-relative-name (org-roam-node-file node)
                                    org-roam-directory))
           (parts (butlast (split-string rel "/"))))
      (mapconcat #'identity (seq-take parts 2) "/")))

  (setq org-roam-node-display-template
      (concat "${type:18} ${title:64} "
              (propertize "${tags:24}" 'face 'org-tag)))

  ;; The backlinks buffer on the right, a third of the frame
  (add-to-list 'display-buffer-alist
               '("\\*org-roam\\*"
                 (display-buffer-in-side-window)
                 (side . right)
                 (window-width . 0.33)
                 (slot . 0)))

  (org-roam-db-autosync-mode))

;; Ask for the area once per capture and reuse the answer everywhere
;; in the template: in the path, the property, the category, the tag.
(defvar my/org-area-choice nil)
(defvar my/org-topic-choice nil)

(defun my/org-pick-area ()
  "Return the area for the capture in progress, asking once."
  (or my/org-area-choice
      (setq my/org-area-choice
            (completing-read "Area: " my/org-areas nil t))))

(defun my/org-pick-topic ()
  "Return the knowledge topic, asking once.
Completes over topics that already exist for the chosen area, but any
new name is accepted: knowledge/coding/python, knowledge/work/pcs7."
  (or my/org-topic-choice
      (setq my/org-topic-choice
            (let* ((dir (expand-file-name
                         (concat "knowledge/" (my/org-pick-area)) my/org-dir))
                   (existing
                    (when (file-directory-p dir)
                      (seq-remove
                       (lambda (d) (string= d "attachments"))
                       (seq-filter
                        (lambda (d) (file-directory-p (expand-file-name d dir)))
                        (directory-files dir nil "\\`[^.]"))))))
              (completing-read "Topic: " existing nil nil)))))

(add-hook 'org-capture-after-finalize-hook
          (lambda () (setq my/org-area-choice nil
                           my/org-topic-choice nil)))

;; org-capture will not create missing directories on its own
(add-hook 'org-roam-capture-new-node-hook
          (lambda ()
            (when buffer-file-name
              (make-directory (file-name-directory buffer-file-name) t))))

;; ${title} is used verbatim for file and folder names, so type the name
;; in kebab-case at the prompt. The #+title line gets the same string;
;; rewrite it by hand afterwards for a readable title. No slugification.
;;
;; DIR is set with #+PROPERTY, not in the property drawer: a keyword
;; becomes a global buffer property that every heading inherits, which
;; is what org-attach needs to skip its data/<id>/ store.
(setq org-roam-capture-templates
      '(("p" "project" plain ""
         :target (file+head
                  "projects/%(my/org-pick-area)/${title}/${title}.org"
                  ":PROPERTIES:\n:TYPE: project\n:AREA: %(my/org-pick-area)\n:STATUS: active\n:STARTED: %U\n:END:\n#+title: ${title}\n#+category: %(my/org-pick-area)\n#+filetags: :project:%(my/org-pick-area):\n#+property: DIR attachments\n\n* Tasks\n\n** TODO %?\n\n*** Result\n\n* Links\n\n* Log\n")
         :unnarrowed t)

        ("k" "knowledge" plain "%?"
         :target (file+head
                  "knowledge/%(my/org-pick-area)/%(my/org-pick-topic)/${title}.org"
                  ":PROPERTIES:\n:TYPE: knowledge\n:AREA: %(my/org-pick-area)\n:TOPIC: %(my/org-pick-topic)\n:END:\n#+title: ${title}\n#+category: %(my/org-pick-area)\n#+filetags: :knowledge:%(my/org-pick-area):\n#+property: DIR attachments\n")
         :unnarrowed t)

        ("c" "calendar" plain "%?"
         :target (file+head
                  "calendar/${title}.org"
                  ":PROPERTIES:\n:TYPE: calendar\n:AREA: %(my/org-pick-area)\n:END:\n#+title: ${title}\n#+category: %(my/org-pick-area)\n#+filetags: :calendar:%(my/org-pick-area):\n")
         :unnarrowed t)

        ("d" "plain note" plain "%?"
         :target (file+head "${title}.org" "#+title: ${title}\n")
         :unnarrowed t)))

;; --- Migration helper -----------------------------
;; org-roam only indexes files that carry a file-level :ID:. Existing
;; notes have none. Run once after switching org-roam-directory.

(defun my/org-roam-add-ids-to-all ()
  "Give every Org file under `org-roam-directory' a file-level ID."
  (interactive)
  (let ((count 0))
    (dolist (file (directory-files-recursively org-roam-directory "\\.org$"))
      (unless (string-match-p "/archive/" file)
        (with-current-buffer (find-file-noselect file)
          (goto-char (point-min))
          (unless (org-id-get)
            (org-id-get-create)
            (setq count (1+ count))
            (save-buffer)))))
    (org-roam-db-sync)
    (message "Added %d file IDs, database resynced" count)))

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
             '("\\*\\(vterm\\|vterminal<[0-9]+>\\|compilation\\)\\*"
               (display-buffer-reuse-window display-buffer-in-side-window)
               (side . bottom)
               (slot . 0)
               (window-height . 0.3)
               (dedicated . t)))

(use-package multi-vterm
  :after vterm
  :bind (("C-c t"   . multi-vterm-project)
         ("C-c T"   . multi-vterm)
         ("C-c C-n" . multi-vterm-next)
         ("C-c C-p" . multi-vterm-prev))
  :custom
  (multi-vterm-dedicated-window-height-percent 30))
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
        treemacs-file-ignore-globs         '("*/__pycache__" "*/.mypy_cache"
                                             "*/node_modules" "*.pyc")
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
