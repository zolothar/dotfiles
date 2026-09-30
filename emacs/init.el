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
;;   16. Dirvish
;;   17. Markdown
;;   18. Workouts

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

;; Programs installed outside the system PATH. Set early, so every
;; later executable-find sees them. A GUI Emacs on macOS does not
;; inherit the shell PATH at all, hence the Homebrew entries.
(dolist (dir (append (list (expand-file-name "~/.local/bin"))  ; pipx
                     (when (eq system-type 'darwin)
                       '("/opt/homebrew/bin" "/opt/homebrew/sbin"))))
  (when (file-directory-p dir)
    (add-to-list 'exec-path dir)
    (setenv "PATH" (concat dir ":" (getenv "PATH")))))

;; macOS keyboard: Command is Meta, Option stays free for typing
;; special characters
(when (eq system-type 'darwin)
  (setq mac-command-modifier 'meta
        mac-option-modifier 'none))

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

;; This is the only absolute size; everything else is relative to it.
(set-face-attribute 'default nil :family "JetBrains Mono" :height 110)

;; Machine-specific overrides. Only what genuinely differs between
;; machines belongs there (font size); everything OS-dependent is
;; handled in this file with system-type checks.
(let ((local (expand-file-name "local.el" user-emacs-directory)))
  (when (file-exists-p local)
    (load local)))
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

;; Keep buffers in sync with the disk: files changed by other programs
;; (git, scripts) and directory listings changed from another Dired or
;; Dirvish buffer, such as a rename done in the side panel.
(setq global-auto-revert-non-file-buffers t   ; Dired and Dirvish listings too
      auto-revert-verbose nil                  ; no "Reverting buffer" messages
      dired-auto-revert-buffer t)              ; refresh a listing on revisit
(global-auto-revert-mode 1)

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
  '("routine" "home" "work" "coding" "road" "workouts" "fun" "system" "social")
  "Areas of life. Used as Org CATEGORY and as a tag.
Adding one here also needs a group in `org-super-agenda-groups' and a
colour in `my/org-area-colors' (section 10).")

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

;; --- Area and topic prompts -----------------------
;; Shared by org-capture (section 10) and org-roam (section 14).
;; Ask once per capture and reuse the answer everywhere in a template:
;; in the path, the property, the category and the tag.
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

;; --- Tags and properties --------------------------

;; Types are mutually exclusive, areas are not enforced but listed
;; for completion. C-c C-q on a heading opens the selector.
(setq org-tag-alist
      `((:startgroup)
        ("project"   . ?p)
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

;; --- Folding state --------------------------------
;; Remember which headings were folded and unfolded, across Emacs
;; restarts and file reopenings. The state is written when a file is
;; saved or killed and restored when it is opened. Files never seen
;; before open in the default below: every heading, bodies folded.
(setq org-startup-folded 'content)

(use-package org-visibility
  :after org
  :demand t
  :bind (:map org-visibility-mode-map
              ;; Save folding even when the text itself is unchanged
              ("C-x C-v" . org-visibility-force-save))
  :custom
  (org-visibility-include-paths (list (file-truename my/org-dir)))
  (org-visibility-exclude-paths
   (mapcar (lambda (d) (file-truename (expand-file-name d my/org-dir)))
           '("archive" "templates")))
  :config
  (org-visibility-mode 1))

;; --------------------------------------------------
;; 10. Org capture, agenda and calendar
;; --------------------------------------------------

;; --- Which files the agenda scans -----------------
;; Only tasks and calendar blocks. Knowledge files hold no scheduled
;; items, so scanning them would only slow the agenda down.
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
;; %(my/org-pick-area) asks for the area once and reuses the answer.
(setq org-capture-templates
      '(("t" "Task to inbox" entry
         (file "~/org/inbox.org")
         "* TODO %?\n  %U\n  %a" :empty-lines 1)

        ("s" "Scheduled task" entry
         (file "~/org/inbox.org")
         "* TODO %? :%(my/org-pick-area):\n  SCHEDULED: %^{When}T\n  %U"
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
         "* %^{Title} :%(my/org-pick-area):\n  :PROPERTIES:\n  :CATEGORY: %(my/org-pick-area)\n  :END:\n  %^{When}T"
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
      ;; Keep finished tasks in their slots: the day stays a record of
      ;; what was actually done, not only of what is left
      org-agenda-skip-scheduled-if-done nil
      org-agenda-skip-deadline-if-done nil
      org-agenda-skip-timestamp-if-done nil
      org-agenda-window-setup 'current-window
      org-agenda-restore-windows-after-quit t)

;; --- Grouping -------------------------------------

(use-package org-super-agenda
  :after org-agenda
  :config
  ;; Everything with a time of day lands in the first group and is laid
  ;; out on the time grid. The area groups below hold only untimed
  ;; items: tasks without an hour, deadlines, inbox.
  (setq org-super-agenda-groups
        '((:name "Schedule"   :time-grid t         :order 1)
          (:name "Overdue"    :deadline past       :order 2)
          (:name "Due today"  :deadline today      :order 3)
          (:name "Work"       :category "work"     :order 10)
          (:name "Coding"     :category "coding"   :order 11)
          (:name "System"     :category "system"   :order 12)
          (:name "Home"       :category "home"     :order 13)
          (:name "Workouts"   :category "workouts" :order 14)
          (:name "Fun"        :category "fun"      :order 15)
          (:name "Social"     :category "social"   :order 16)
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

;; org-timeblock wants a face NAME per tag, not a list of colours.
;; One face per area, coloured from the Kanagawa palette. Routine and
;; road are deliberately dim: they are background, not work. An area
;; missing here is simply drawn in org-timeblock's default colours.
(defvar my/org-area-colors
  '(("routine"  "#2a2a37" "#727169")
    ("road"     "#2a2a37" "#727169")
    ("work"     "#2d4f67" "#c8c093")
    ("coding"   "#43242b" "#c8c093")
    ("system"   "#49443c" "#c8c093")
    ("home"     "#223249" "#c8c093")
    ("workouts" "#2b3328" "#c8c093")
    ("fun"      "#54536d" "#c8c093")
    ("social"   "#3f3452" "#c8c093"))
  "Area to (BACKGROUND FOREGROUND) for timeblocks.")

(dolist (spec my/org-area-colors)
  (custom-declare-face
   (intern (concat "my-timeblock-" (car spec)))
   `((t :background ,(nth 1 spec) :foreground ,(nth 2 spec)))
   (format "Timeblock face for the %s area." (car spec))))

(use-package org-timeblock
  :bind ("C-c b" . org-timeblock)
  :config
  ;; The picture always fits the window height and never scrolls, so the
  ;; only way to make blocks taller is to show less: fewer days, fewer
  ;; hours. V changes the number of days live, v cycles the hour range.
  (setq org-timeblock-span 1                  ; one wide day column
        org-timeblock-scale-options '(5 . 23)) ; waking hours only
  (setq org-timeblock-tag-colors
        (mapcar (lambda (spec)
                  (cons (car spec) (intern (concat "my-timeblock-" (car spec)))))
                my/org-area-colors)))

;; org-timeblock skips DONE entries with a hard-coded check and has no
;; option for it. Hide the done state from that one function, so that
;; finished tasks stay drawn, as they do in the agenda. Archived
;; entries are filtered by a separate check and stay hidden.
(require 'cl-lib)

(defun my/org-timeblock-keep-done (orig &rest args)
  "Call ORIG with ARGS while every entry counts as not done."
  (cl-letf (((symbol-function 'org-entry-is-done-p) #'ignore))
    (apply orig args)))

(with-eval-after-load 'org-timeblock
  (advice-add 'org-timeblock-get-buffer-entries-all :around
              #'my/org-timeblock-keep-done))

;; Smaller text in the timeblock view. The package sizes block text from
;; the frame's default font (font-info of face-font) and wraps it using
;; default-font-width/-height, none of which see a buffer-local
;; text-scale. Scale all three together while an org-timeblock buffer is
;; current, so text shrinks and still wraps to the smaller size.
(defvar my/org-timeblock-font-scale 0.9
  "Text size in org-timeblock relative to the default font.")

(defun my/org-timeblock-scale-metric (orig &rest args)
  "Scale ORIG's pixel result in org-timeblock buffers."
  (let ((value (apply orig args)))
    (if (derived-mode-p 'org-timeblock-mode)
        (max 1 (round (* value my/org-timeblock-font-scale)))
      value)))

(defun my/org-timeblock-scale-font-info (orig &rest args)
  "Scale the pixel size reported by ORIG in org-timeblock buffers."
  (let ((info (apply orig args)))
    (if (and (vectorp info) (derived-mode-p 'org-timeblock-mode))
        (let ((copy (copy-sequence info)))
          (aset copy 2 (max 1 (round (* (aref info 2)
                                        my/org-timeblock-font-scale))))
          copy)
      info)))

(advice-add 'default-font-width  :around #'my/org-timeblock-scale-metric)
(advice-add 'default-font-height :around #'my/org-timeblock-scale-metric)
(advice-add 'font-info           :around #'my/org-timeblock-scale-font-info)

;; --- Queries (the Dataview replacement) -----------

(use-package org-ql
  :bind ("C-c q" . org-ql-search))

;; --- Rescan agenda files --------------------------
;; The file list is built at startup. Rebuild it whenever something
;; reads it, so new projects and generated weeks appear without a
;; restart: the agenda, org-timeblock and the week generator.
(defun my/org-agenda-files-refresh (&rest _)
  "Rebuild `org-agenda-files' from disk."
  (setq org-agenda-files (my/org-agenda-files)))

(advice-add 'org-agenda :before #'my/org-agenda-files-refresh)
(with-eval-after-load 'org-timeblock
  (advice-add 'org-timeblock :before #'my/org-agenda-files-refresh))

;; --- Week generation from day templates -----------
;;
;;   templates/<day>-template.org  one file per day, any fixed date inside
;;   my/org-week-plan              which template falls on which weekday
;;   calendar/<YYYY>-W<NN>.org     generated week, edited freely afterwards
;;
;; A template is a flat chronological list: a heading, one area tag, one
;; timestamp. The generator moves the timestamps to the target date and
;; derives each block's CATEGORY from its area tag. Generated blocks
;; carry no repeaters, so any single block can be deleted, moved or
;; stretched without touching other days.

(defvar my/org-template-dir (expand-file-name "templates" my/org-dir)
  "Day templates. Not scanned by the agenda, excluded from org-roam.")

(defvar my/org-week-plan
  '((1 . "monday-template")
    (2 . "tuesday-template")
    (3 . "wednesday-template")
    (4 . "thursday-template")
    (5 . "friday-template")
    (6 . "saturday-template")
    (0 . "sunday-template"))
  "Weekday number (0 = Sunday) to a template name in `my/org-template-dir'.
Several weekdays may point at the same template.")

(defun my/org-date+ (time n)
  "Return TIME shifted by N days. Uses decoded time, so DST-safe."
  (let ((d (decode-time time)))
    (setf (decoded-time-day d) (+ (decoded-time-day d) n))
    (encode-time d)))

(defun my/org-monday-of (time)
  "Return the Monday of the week containing TIME."
  (let ((dow (decoded-time-weekday (decode-time time))))
    (my/org-date+ time (- (mod (- dow 1) 7)))))

(defun my/org-blocks--render (template date)
  "Return TEMPLATE's blocks moved to DATE, or nil if TEMPLATE is missing."
  (let ((file (expand-file-name (concat template ".org") my/org-template-dir))
        (stamp (let ((system-time-locale "C"))
                 (format-time-string "%Y-%m-%d %a" date))))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        ;; Drop the template's header: #+keywords, blank lines and a
        ;; file-level property drawer, if one was ever added
        (goto-char (point-min))
        (while (and (not (eobp))
                    (cond ((looking-at-p "^\\(#\\+\\|[ \t]*$\\)")
                           (forward-line 1) t)
                          ((looking-at-p "^[ \t]*:PROPERTIES:")
                           (re-search-forward "^[ \t]*:END:" nil 'move)
                           (forward-line 1) t))))
        (delete-region (point-min) (point))
        ;; Move every timestamp to DATE, keeping the times
        (goto-char (point-min))
        (while (re-search-forward
                "<[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} [^ >]+" nil t)
          (replace-match (concat "<" stamp) t t))
        ;; CATEGORY from the area tag
        (delay-mode-hooks (org-mode))
        (org-map-entries
         (lambda ()
           (when-let ((area (seq-find (lambda (tag) (member tag my/org-areas))
                                      (org-get-tags nil t))))
             (org-set-property "CATEGORY" area))))
        ;; Demote by one level to nest under the day heading
        (goto-char (point-min))
        (while (re-search-forward "^\\*" nil t)
          (replace-match "**"))
        (buffer-string)))))

(defun my/org-week--write (start)
  "Write the generated week containing START. Return the file name."
  (let* ((monday (my/org-monday-of start))
         (file (expand-file-name
                (let ((system-time-locale "C"))
                  (format-time-string "%G-W%V.org" monday))
                (expand-file-name "calendar" my/org-dir))))
    (if (and (file-exists-p file)
             (not (y-or-n-p (format "%s exists, overwrite? "
                                    (file-name-nondirectory file)))))
        (message "Skipped %s" (file-name-nondirectory file))
      (with-temp-file file
        (insert (let ((system-time-locale "C"))
                  (format-time-string
                   "#+title: Week of %Y-%m-%d\n\n"
                   monday)))
        (dotimes (n 7)
          (let* ((date (my/org-date+ monday n))
                 (dow (decoded-time-weekday (decode-time date)))
                 (template (cdr (assq dow my/org-week-plan)))
                 (body (and template (my/org-blocks--render template date))))
            (insert (let ((system-time-locale "C"))
                      (format-time-string "* %Y-%m-%d %a\n" date)))
            (cond (body (insert body) (unless (bolp) (insert "\n")))
                  (template (insert (format "No template: %s\n" template)))))))
      (my/org-agenda-files-refresh))
    file))

(defun my/org-week-generate (start)
  "Generate the week containing START from day templates and open it."
  (interactive (list (org-read-date nil t nil "Any day of the week")))
  (find-file (my/org-week--write start)))

(defun my/org-weeks-generate (start count)
  "Generate COUNT consecutive weeks, the first one containing START."
  (interactive (list (org-read-date nil t nil "Any day of the first week")
                     (read-number "Weeks: " 4)))
  (dotimes (i count)
    (my/org-week--write (my/org-date+ start (* 7 i))))
  (message "Generated %d week(s)" count))

(global-set-key (kbd "C-c n w") #'my/org-week-generate)
(global-set-key (kbd "C-c n W") #'my/org-weeks-generate)

;; --------------------------------------------------
;; 11. Org reading and writing
;; --------------------------------------------------

;; Reveal hidden markup only while the cursor is inside it
(use-package org-appear
  :hook (org-mode . org-appear-mode))

(setq org-auto-align-tags nil
      org-tags-column 0
      org-catch-invisible-edits 'show-and-error
      org-special-ctrl-a/e t
      org-insert-heading-respect-content t
      org-pretty-entities t
      org-ellipsis "…")

;; Screenshots and clipboard images straight into a note.
;; Linux needs scrot and xclip on X11; on Wayland install grim + slurp
;; and use "grim -g \"$(slurp)\" %s" instead. macOS has screencapture.
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
        org-download-screenshot-method
        (if (eq system-type 'darwin) "screencapture -i %s" "scrot -s %s")))

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
  (cond ((eq system-type 'darwin)
         ;; osascript prints the HTML hex-encoded as <<data HTML3C68...>>;
         ;; perl pulls out the hex digits and decodes them
         (concat "osascript -e 'the clipboard as \"HTML\"' 2>/dev/null"
                 " | perl -ne 'print pack(\"H*\", $1) if /HTML([0-9A-Fa-f]+)/'"))
        ((executable-find "wl-paste") "wl-paste --no-newline --type text/html")
        ((executable-find "xclip")    "xclip -selection clipboard -t text/html -o"))
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

;; First jar that exists: a manual download on Linux, Homebrew on macOS
(setq org-plantuml-jar-path
      (seq-find #'file-exists-p
                (list (expand-file-name "~/packages/jar/plantuml.jar")
                      "/opt/homebrew/opt/plantuml/libexec/plantuml.jar")))

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
   '("/archive/" "/templates/" "/calendar/" "/attachments/" "/\\.git/"))
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
      '(("p" "project" plain "%?"
         :target (file+head
                  "projects/%(my/org-pick-area)/${title}/${title}.org"
                  ":PROPERTIES:\n:TYPE: project\n:AREA: %(my/org-pick-area)\n:STATUS: active\n:STARTED: [%<%Y-%m-%d %a>]\n:FINISHED:\n:END:\n#+title: ${title}\n#+category: %(my/org-pick-area)\n#+filetags: :project:%(my/org-pick-area):\n#+property: DIR attachments\n\n* Tasks\n")
         :unnarrowed t)

        ("k" "knowledge" plain "%?"
         :target (file+head
                  "knowledge/%(my/org-pick-area)/%(my/org-pick-topic)/${title}.org"
                  ":PROPERTIES:\n:TYPE: knowledge\n:AREA: %(my/org-pick-area)\n:TOPIC: %(my/org-pick-topic)\n:END:\n#+title: ${title}\n#+category: %(my/org-pick-area)\n#+filetags: :knowledge:%(my/org-pick-area):\n#+property: DIR attachments\n")
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
      (when (org-roam-file-p file)            ; honours the exclusions
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


(use-package magit
  :bind ("C-x g" . magit-status))

;; Show added, changed and removed lines in the fringe
(use-package diff-hl
  :hook ((prog-mode . diff-hl-mode)
         (org-mode  . diff-hl-mode)
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
  (vterm-kill-buffer-on-exit nil))

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
  :bind (("C-c t" . multi-vterm-project)      ; one session per project
         ("C-c T" . multi-vterm)              ; another session here
         :map vterm-mode-map
         ("C-c t" . delete-window)            ; same key hides it again
         ("M-n"   . multi-vterm-next)         ; cycle sessions, terminal only
         ("M-p"   . multi-vterm-prev))
  :custom
  (multi-vterm-dedicated-window-height-percent 30))

;; --------------------------------------------------
;; 16. Dirvish
;; --------------------------------------------------
;;
;; Dirvish replaces the look of every Dired buffer but keeps all Dired
;; keys: C-x d, C-x C-j and anything else that opens Dired now opens
;; Dirvish. It adds a file preview, a side panel, git state and a set
;; of transient menus; press ? in any Dirvish buffer for the full list.

;; Dired needs GNU ls for the listing switches below. Linux has it;
;; on macOS it comes from `brew install coreutils' as gls.
(when (and (eq system-type 'darwin) (executable-find "gls"))
  (setq insert-directory-program "gls"))

(setq dired-listing-switches
      "-l --almost-all --human-readable --group-directories-first --no-group"
      dired-dwim-target t                 ; copy/move defaults to the other pane
      delete-by-moving-to-trash t)        ; D sends to the trash, not oblivion

(use-package dirvish
  :init
  (dirvish-override-dired-mode)
  :custom
  ;; Jump targets for `a'. A custom option: setq would not take effect.
  (dirvish-quick-access-entries
   '(("h" "~/"                "Home")
     ("o" "~/org/"            "Org")
     ("p" "~/org/projects/"   "Projects")
     ("k" "~/org/knowledge/"  "Knowledge")
     ("c" "~/org/calendar/"   "Calendar")
     ("t" "~/org/templates/"  "Templates")
     ("w" "~/org/projects/workouts/training/" "Training")
     ("e" "~/dotfiles/"       "Dotfiles")
     ("d" "~/Downloads/"      "Downloads")))
  :config
  ;; Columns shown next to each file. The order matters for some.
  (setq dirvish-attributes
        '(vc-state subtree-state nerd-icons collapse file-time file-size)
        dirvish-side-attributes
        '(vc-state subtree-state nerd-icons collapse))
  (setq dirvish-mode-line-format
        '(:left (sort symlink) :right (omit yank index)))
  ;; Huge directories are listed asynchronously with fd. Debian and
  ;; Ubuntu ship it as fdfind; point dirvish at whichever name exists.
  ;; Without fd at all, dirvish still works, only big listings are slower.
  (setq dirvish-large-directory-threshold 20000
        dirvish-fd-program (if (executable-find "fd") "fd" "fdfind"))
  ;; Uncomment to make the side panel chase the current file around.
  ;; Off by default: the panel stays on the directory you opened.
  ;; (dirvish-side-follow-mode 1)
  :bind
  (("C-c f" . dirvish)                    ; full-frame file manager
   ("C-c e" . dirvish-side)               ; side panel, toggles
   :map dirvish-mode-map
   ("?"   . dirvish-dispatch)             ; cheatsheet of everything below
   ("a"   . dirvish-quick-access)         ; jump to an entry defined above
   ("f"   . dirvish-file-info-menu)       ; copy path, name, size, ...
   ("s"   . dirvish-quicksort)            ; sort by name, time, size, ...
   ("y"   . dirvish-yank-menu)            ; paste/move marked files here
   ("N"   . dirvish-narrow)               ; filter the listing as you type
   ("v"   . dirvish-vc-menu)              ; git actions on the file
   ("TAB" . dirvish-subtree-toggle)       ; expand a directory in place
   ("^"   . dirvish-history-last)         ; previous directory
   ("M-b" . dirvish-history-go-backward)
   ("M-f" . dirvish-history-go-forward)
   ("M-t" . dirvish-layout-toggle)))      ; preview pane on and off

;; Open the side panel on ~/org at startup without taking focus.
;; Remove this hook to start with a clean frame instead.
(defun my/dirvish-side-start ()
  "Show the Dirvish side panel on ~/org, keep point where it was."
  (let ((win (selected-window))
        (default-directory (file-name-as-directory my/org-dir)))
    (dirvish-side)
    (select-window win)))

(add-hook 'emacs-startup-hook #'my/dirvish-side-start)

;; --------------------------------------------------
;; 17. Markdown
;; --------------------------------------------------

(use-package markdown-mode
  :mode ("\\.md\\'" . markdown-mode))

;; --------------------------------------------------
;; 18. Workouts
;; --------------------------------------------------
;;
;;   projects/workouts/training/training.org          project file: recurring tasks
;;   projects/workouts/training/journal/YYYY.org      one journal per year: every
;;                                                    session and measurement, datetree
;;   projects/workouts/training/programs/<name>-<date>.org  one file per program
;;   projects/workouts/training/attachments/          photos
;;
;; A program is never edited into the next one: a new program is a new
;; file, and the date at the end of its name is its first day. The
;; program for a session is the newest one whose date is not after the
;; session's date.
;;
;; Sessions are planned ahead as scheduled TODO entries, filed under
;; their day in that year's journal. In a program, a strength session
;; is a heading with a SESSION property and a table with "Exercise" and
;; "Start" columns; "4 × 8" in Start gives that exercise four set
;; columns. The "Last" column shows the most recent real result of each
;; exercise across all journals, whatever program or day it was done
;; under. Deload entries are skipped there.
;;
;; Boxing is one session too: warm-up, solo work, coach. Program
;; sections under the boxing heading marked :JOURNAL: copy (the solo
;; work) are copied into each boxing entry, followed by the coach part.
;;
;; Every session entry starts with the same items, filled in after the
;; session: session RPE, pain, injury.

(defvar my/workout-dir
  (expand-file-name "projects/workouts/training" my/org-dir)
  "Training project folder.")

(defvar my/workout-journal-dir (expand-file-name "journal" my/workout-dir)
  "One journal per year, named YYYY.org.")

(defvar my/workout-program-dir (expand-file-name "programs" my/workout-dir)
  "One Org file per program, named <anything>-YYYY-MM-DD.org.")

(defvar my/workout-measures
  '(("WEIGHT"    . "Weight, kg")
    ("ARM_L"     . "Arm L, cm")
    ("ARM_R"     . "Arm R, cm")
    ("CHEST"     . "Chest, cm")
    ("SHOULDERS" . "Shoulders, cm")
    ("WAIST"     . "Waist, cm")
    ("HIPS"      . "Hips, cm")
    ("THIGH_L"   . "Thigh L, cm")
    ("THIGH_R"   . "Thigh R, cm")
    ("BODY_FAT"  . "Body fat, pct"))
  "Measurement properties in prompt order, with their labels.
Used by the capture template and by `my/workout-measurements'.")

(defconst my/workout--session-items
  "- Session RPE :: \n- Pain :: \n- Injury :: \n"
  "Items every session entry starts with, filled in after the session.")

(defvar my/workout--session-day nil
  "Absolute day of the session being planned, set by `my/workout--target'.")

(defvar my/workout--session-stamp nil
  "SCHEDULED timestamp of the session being planned.")

;; --- Programs -------------------------------------

(defun my/workout--programs ()
  "Program files as (START-DAY . FILE), oldest first.
START-DAY is the absolute day number of the date ending the file name."
  (when (file-directory-p my/workout-program-dir)
    (sort (delq nil
                (mapcar
                 (lambda (file)
                   (when (string-match
                          "\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)\\.org\\'"
                          file)
                     (cons (org-time-string-to-absolute (match-string 1 file))
                           file)))
                 (directory-files my/workout-program-dir t "\\.org\\'")))
          (lambda (a b) (< (car a) (car b))))))

(defun my/workout--program (&optional day)
  "(START-DAY . FILE) of the program in force on DAY (default today)."
  (let ((day (or day (org-today))))
    (car (last (seq-filter (lambda (p) (<= (car p) day))
                           (my/workout--programs))))))

(defun my/workout--week (&optional day)
  "Week number of DAY (default today) in its program, from 1, or nil."
  (let ((day (or day (org-today))))
    (when-let ((p (my/workout--program day)))
      (1+ (/ (- day (car p)) 7)))))

;; --- Journals -------------------------------------

(defun my/workout--journals ()
  "Journal files, oldest year first."
  (when (file-directory-p my/workout-journal-dir)
    (directory-files my/workout-journal-dir t "\\`[0-9]\\{4\\}\\.org\\'")))

(defun my/workout--journal (year)
  "Journal file for YEAR, created with its header when missing."
  (let ((file (expand-file-name (format "%d.org" year) my/workout-journal-dir)))
    (unless (file-exists-p file)
      (make-directory my/workout-journal-dir t)
      (write-region (format (concat "#+title: Training journal %d\n"
                                    "#+category: workouts\n"
                                    "#+property: DIR ../attachments\n")
                            year)
                    nil file))
    file))

(defun my/workout--in (file fn)
  "Call FN in FILE's buffer, widened, point at the start.
Return FN's value, or nil when FILE is nil or missing."
  (when (and file (file-exists-p file))
    (with-current-buffer (find-file-noselect file)
      (org-with-wide-buffer
       (goto-char (point-min))
       (funcall fn)))))

(defun my/workout--map-journals (fn match)
  "Call FN on every journal entry matching MATCH, oldest first.
Return FN's values as one list."
  (mapcan (lambda (file)
            (my/workout--in file (lambda () (org-map-entries fn match 'file))))
          (my/workout--journals)))

(defun my/workout--goto-day (time)
  "Go to TIME's day in its year's journal, creating what is missing."
  (let ((d (decode-time time)))
    (set-buffer (org-capture-target-buffer (my/workout--journal (nth 5 d))))
    (widen)
    (org-datetree-find-date-create (list (nth 4 d) (nth 3 d) (nth 5 d)))))

;; --- Reading entries ------------------------------

(defun my/workout--table-here ()
  "First table in the subtree at point, as `org-table-to-lisp' returns it."
  (save-excursion
    (let ((end (save-excursion (org-end-of-subtree t) (point))))
      (when (re-search-forward "^[ \t]*|" end t)
        (org-table-to-lisp)))))

(defun my/workout--field (rec key)
  "Value of column KEY in REC, \"\" when absent."
  (or (cdr (assoc key rec)) ""))

(defun my/workout--records (table)
  "Rows of TABLE that name an exercise, as alists keyed by header.
Tables without an \"Exercise\" column, such as the coach table of
a boxing entry, give nothing."
  (let ((rows (seq-filter #'listp table)))
    (seq-remove (lambda (rec) (string-empty-p (my/workout--field rec "Exercise")))
                (mapcar (lambda (row) (seq-mapn #'cons (car rows) row))
                        (cdr rows)))))

(defun my/workout--sets (rec)
  "Values of REC's set columns, those headed 1, 2, 3…, in order."
  (mapcar #'cdr (seq-filter (lambda (cell) (string-match-p "\\`[0-9]+\\'" (car cell)))
                            rec)))

(defun my/workout--done-p (rec)
  "Non-nil when at least one set of REC is filled in."
  (seq-some (lambda (s) (not (string-empty-p s))) (my/workout--sets rec)))

(defun my/workout--item (name)
  "Value of the \"- NAME ::\" item in the entry at point, \"\" when empty."
  (save-excursion
    (let ((end (save-excursion (org-end-of-subtree t) (point))))
      (if (re-search-forward
           (format "^- %s ::[ \t]*\\(.*\\)$" (regexp-quote name)) end t)
          (string-trim (match-string-no-properties 1))
        ""))))

(defun my/workout--date ()
  "Date of the datetree day that the entry at point sits under."
  (let ((day (or (car (last (org-get-outline-path))) "")))
    (substring day 0 (min 10 (length day)))))

(defun my/workout--align (text)
  "TEXT, an Org table, aligned."
  (with-temp-buffer
    (delay-mode-hooks (org-mode))
    (insert text)
    (goto-char (point-min))
    (org-table-align)
    (string-trim-right (buffer-string))))

;; --- Results --------------------------------------

(defun my/workout--start-sets (start)
  "Number of sets in a program Start cell such as \"3 × 7 / leg\"; 3 if none."
  (if (string-match "\\`[ \t]*\\([0-9]+\\)[ \t]*[×xX]" start)
      (string-to-number (match-string 1 start))
    3))

(defun my/workout--exercises (session &optional day)
  "Exercises of SESSION in the program in force on DAY, as (NAME . SETS)."
  (my/workout--in
   (cdr (my/workout--program day))
   (lambda ()
     (when-let ((pos (org-find-property "SESSION" session)))
       (goto-char pos)
       (mapcar (lambda (rec)
                 (cons (my/workout--field rec "Exercise")
                       (my/workout--start-sets (my/workout--field rec "Start"))))
               (my/workout--records (my/workout--table-here)))))))

(defun my/workout--last-results (&optional stop)
  "Hash of exercise name to its latest filled-in row, deloads skipped.
STOP, a (JOURNAL-NAME . POS) pair such as (\"2027.org\" . 1234), keeps
only entries above POS in that journal and in earlier ones."
  (let ((results (make-hash-table :test #'equal)))
    (catch 'done
      (dolist (file (my/workout--journals))
        (let ((name (file-name-nondirectory file)))
          (when (and stop (string< (car stop) name))
            (throw 'done nil))
          (my/workout--in
           file
           (lambda ()
             ;; Journals and their datetrees run in date order, so a
             ;; later row simply overwrites an earlier one
             (org-map-entries
              (lambda ()
                (when (or (null stop)
                          (not (equal name (car stop)))
                          (< (point) (cdr stop)))
                  (dolist (rec (my/workout--records (my/workout--table-here)))
                    (when (my/workout--done-p rec)
                      (puthash (my/workout--field rec "Exercise") rec results)))))
              "SESSION={.}-deload" 'file))))))
    results))

(defun my/workout--format (rec)
  "REC as \"7/7/6 @8 +5\": reps, RPE of the last set, extra weight."
  (let ((reps (seq-remove #'string-empty-p (my/workout--sets rec)))
        (rpe (my/workout--field rec "RPE"))
        (kg  (my/workout--field rec "+kg")))
    (concat (string-join reps "/")
            (unless (string-empty-p rpe) (concat " @" rpe))
            (unless (string-empty-p kg) (concat " +" kg)))))

(defun my/workout-refresh-last ()
  "Recompute the Last column of the session entry at point.
Only results above this entry, and in earlier journals, count.
Useful when a session was planned before the previous one was done."
  (interactive)
  (save-excursion
    (org-back-to-heading t)
    (let* ((stop (cons (file-name-nondirectory (buffer-file-name)) (point)))
           (end (save-excursion (org-end-of-subtree t) (point)))
           (results (my/workout--last-results stop)))
      (unless (re-search-forward "^[ \t]*|" end t)
        (user-error "No table in this entry"))
      (let* ((header (car (seq-filter #'listp (org-table-to-lisp))))
             (name-col (seq-position header "Exercise"))
             (last-col (seq-position header "Last"))
             (line 2)
             name)
        (unless (and name-col last-col)
          (user-error "Not an exercise table"))
        (while (setq name (org-table-get line (1+ name-col)))
          (let ((rec (gethash (string-trim name) results)))
            (org-table-put line (1+ last-col)
                           (if rec (my/workout--format rec) "")))
          (setq line (1+ line)))
        (org-table-align)))))

;; --- Filling a planned session --------------------

(defun my/workout--target ()
  "Ask for the session date and go to its day in that year's journal.
Takes a date, optionally a time or a range: \"fri 18:30-19:45\"."
  (let (org-time-was-given org-end-time-was-given)
    (let* ((time (org-read-date t t nil "Session (date, time or range): "))
           (stamp (format-time-string
                   (org-time-stamp-format org-time-was-given) time)))
      (setq my/workout--session-day (time-to-days time)
            my/workout--session-stamp
            (if org-end-time-was-given
                (concat (substring stamp 0 -1) "-" org-end-time-was-given ">")
              stamp))
      (my/workout--goto-day time))))

(defun my/workout--measure-target ()
  "Go to today in this year's journal."
  (my/workout--goto-day (current-time)))

(defun my/workout-scheduled ()
  "SCHEDULED timestamp of the session being planned."
  my/workout--session-stamp)

(defun my/workout-program-name ()
  "File name of the session's program, without directory and extension."
  (let ((p (my/workout--program my/workout--session-day)))
    (if p (file-name-base (cdr p)) "none")))

(defun my/workout-week ()
  "The session's program week as a string, \"\" without a program."
  (let ((week (my/workout--week my/workout--session-day)))
    (if week (number-to-string week) "")))

(defun my/workout-deload-tag ()
  "\"deload:\" when the session falls in a deload week, else \"\".
The program sets the cycle with a #+deload_every: N keyword."
  (let* ((p (my/workout--program my/workout--session-day))
         (every (my/workout--in
                 (cdr p)
                 (lambda ()
                   (let ((v (cadr (assoc "DELOAD_EVERY"
                                         (org-collect-keywords
                                          '("DELOAD_EVERY"))))))
                     (and v (string-to-number v))))))
         (week (my/workout--week my/workout--session-day)))
    (if (and every (> every 0) week (zerop (% week every)))
        "deload:"
      "")))

(defun my/workout-table (session)
  "Org table for SESSION: program exercises, last results alongside.
There are as many set columns as the largest set count in Start."
  (let* ((results (my/workout--last-results))
         (exercises (my/workout--exercises session my/workout--session-day))
         (sets (apply #'max 1 (mapcar #'cdr exercises)))
         (blank (apply #'concat (make-list sets " |"))))
    (my/workout--align
     (concat "| Exercise |"
             (mapconcat (lambda (i) (format " %d |" i)) (number-sequence 1 sets) "")
             " RPE | +kg | Last |\n|-\n"
             (mapconcat
              (lambda (ex)
                (let ((rec (gethash (car ex) results)))
                  (format "| %s |%s | | %s |\n"
                          (car ex) blank (if rec (my/workout--format rec) ""))))
              exercises "")))))

(defun my/workout-coach-table ()
  "Empty table for what was done in the hour with the coach."
  (my/workout--align
   (concat "| Drill | Rounds × time | Notes |\n|-\n"
           (apply #'concat (make-list 5 "| | | |\n")))))

(defun my/workout-last-remarks ()
  "Coach remarks from the last boxing entry, for the second session.
The remarks are the rest of the \"- Coach remarks ::\" line and the
indented lines under it."
  (or (seq-some
       (lambda (file)
         (my/workout--in
          file
          (lambda ()
            (when-let ((pos (car (last (org-map-entries
                                        #'point "SESSION=\"boxing\"" 'file)))))
              (goto-char pos)
              (let ((end (save-excursion (org-end-of-subtree t) (point))))
                (if (not (re-search-forward "^[ \t]*- Coach remarks ::" end t))
                    ""
                  (let ((start (point)))
                    (forward-line 1)
                    (while (and (< (point) end)
                                (looking-at "[ \t]+\\S-\\|[ \t]*$"))
                      (forward-line 1))
                    (string-trim-right
                     (buffer-substring-no-properties start (point))))))))))
       (reverse (my/workout--journals)))
      ""))

;; --- Boxing ---------------------------------------

(defun my/workout--copy-section (text level)
  "Program subtree TEXT from LEVEL, reshaped as a child of a session entry.
The JOURNAL property goes; headings shift so TEXT's top one is level 2,
which capture then places one level below the entry."
  (with-temp-buffer
    (delay-mode-hooks (org-mode))
    (insert text)
    (goto-char (point-min))
    (org-entry-delete (point) "JOURNAL")
    (goto-char (point-min))
    (let ((shift (- 2 level)))
      (while (re-search-forward "^\\(\\*+\\) " nil t)
        (replace-match (make-string (max 1 (+ (length (match-string 1)) shift)) ?*)
                       t t nil 1)))
    (string-trim (buffer-string))))

(defun my/workout--program-sections (session)
  "Sections of SESSION marked :JOURNAL: copy in the session's program.
One string, ready to go under the session entry; nil when none.
Mark only top sections: a marked heading inside a marked one is
copied twice."
  (let ((parts
         (my/workout--in
          (cdr (my/workout--program my/workout--session-day))
          (lambda ()
            (when-let ((pos (org-find-property "SESSION" session)))
              (goto-char pos)
              (org-map-entries
               (lambda ()
                 (cons (org-current-level)
                       (buffer-substring-no-properties
                        (point)
                        (save-excursion (org-end-of-subtree t) (point)))))
               "JOURNAL=\"copy\"" 'tree))))))
    (when parts
      (mapconcat (lambda (part) (my/workout--copy-section (cdr part) (car part)))
                 parts "\n"))))

(defun my/workout-boxing-body ()
  "Body of a boxing entry: the program's solo work, then the coach part."
  (string-join
   (delq nil
         (list (my/workout--program-sections "boxing")
               (concat "** Coach\n\n"
                       "- Focus :: \n"
                       "- Question for the coach :: \n\n"
                       (my/workout-coach-table) "\n\n"
                       "- Coach remarks ::\n  - ")))
   "\n"))

;; --- Views ----------------------------------------

(defun my/workout--show (buffer title header rows)
  "Pop up BUFFER with TITLE and an Org table of HEADER and ROWS.
A row given as the symbol `hline' becomes a horizontal rule."
  (with-current-buffer (get-buffer-create buffer)
    (erase-buffer)
    (delay-mode-hooks (org-mode))
    (insert "#+title: " title "\n\n")
    (let ((start (point)))
      (insert "| " (string-join header " | ") " |\n|-\n")
      (dolist (row rows)
        (insert (if (eq row 'hline)
                    "|-\n"
                  (concat "| " (string-join row " | ") " |\n"))))
      (goto-char start)
      (org-table-align))
    (goto-char (point-min))
    (pop-to-buffer (current-buffer))))

(defun my/workout--logged-exercises ()
  "Every exercise name that appears in a journal session table."
  (delete-dups
   (apply #'append
          (my/workout--map-journals
           (lambda ()
             (mapcar (lambda (rec) (my/workout--field rec "Exercise"))
                     (my/workout--records (my/workout--table-here))))
           "SESSION={.}"))))

(defun my/workout-history (exercise)
  "Show every logged result of EXERCISE, oldest first.
A horizontal rule separates results done under different programs."
  (interactive
   (list (completing-read "Exercise: " (my/workout--logged-exercises) nil t)))
  (let* ((found
          (delq nil
                (my/workout--map-journals
                 (lambda ()
                   (let ((rec (seq-find
                               (lambda (r) (equal (my/workout--field r "Exercise") exercise))
                               (my/workout--records (my/workout--table-here)))))
                     (when (and rec (my/workout--done-p rec))
                       (list (org-entry-get nil "PROGRAM")
                             (concat (my/workout--date)
                                     (if (member "deload" (org-get-tags nil t))
                                         " deload" ""))
                             (or (org-entry-get nil "WEEK") "")
                             (my/workout--sets rec)
                             (my/workout--field rec "RPE")
                             (my/workout--field rec "+kg")))))
                 "SESSION={.}")))
         (sets (apply #'max 1 (mapcar (lambda (f) (length (nth 3 f))) found)))
         (rows '())
         (program nil))
    (dolist (f found)
      (when (and program (not (equal program (nth 0 f))))
        (push 'hline rows))
      (setq program (nth 0 f))
      (push (append (list (nth 1 f) (nth 2 f))
                    (nth 3 f)
                    (make-list (- sets (length (nth 3 f))) "")
                    (list (nth 4 f) (nth 5 f)))
            rows))
    (my/workout--show "*workout-history*" exercise
                      (append '("Date" "Week")
                              (mapcar #'number-to-string (number-sequence 1 sets))
                              '("RPE" "+kg"))
                      (nreverse rows))))

(defun my/workout-sessions ()
  "Show every done session: date, type, week, session RPE, pain, injury."
  (interactive)
  (my/workout--show
   "*workout-sessions*" "Sessions"
   '("Date" "Session" "Week" "RPE" "Pain" "Injury")
   (my/workout--map-journals
    (lambda ()
      (list (my/workout--date)
            (org-get-heading t t t t)
            (or (org-entry-get nil "WEEK") "")
            (my/workout--item "Session RPE")
            (my/workout--item "Pain")
            (my/workout--item "Injury")))
    "SESSION={.}/DONE")))

(defun my/workout-measurements ()
  "Show every measurement entry as one table, oldest first."
  (interactive)
  (my/workout--show
   "*workout-measurements*" "Measurements"
   (append '("Date") (mapcar #'cdr my/workout-measures) '("Photo"))
   (my/workout--map-journals
    (lambda ()
      (append (list (my/workout--date))
              (mapcar (lambda (m) (or (org-entry-get nil (car m)) ""))
                      my/workout-measures)
              (list (if (member "ATTACH" (org-get-tags nil t)) "yes" ""))))
    "measure")))

;; --- Capture --------------------------------------
;; C-c c w opens the workout group. A session is a TODO scheduled on
;; the date you give, filed under that day in that year's journal; fill
;; it in after the session, mark it DONE. Measurements are recorded as
;; they happen and opened at once, ready for a photo.

(defun my/workout--entry (key title session body &optional deload)
  "Capture template KEY planning a SESSION entry titled TITLE with BODY.
The entry starts with the session items; BODY follows them directly.
With DELOAD, the entry is tagged deload in a program's deload week."
  `(,key ,title entry (function my/workout--target)
         ,(concat "* TODO " title " :workouts:"
                  (if deload "%(my/workout-deload-tag)" "") "\n"
                  "SCHEDULED: %(my/workout-scheduled)\n"
                  ":PROPERTIES:\n"
                  ":SESSION: " session "\n"
                  ":PROGRAM: %(my/workout-program-name)\n"
                  ":WEEK: %(my/workout-week)\n"
                  ":END:\n\n"
                  my/workout--session-items
                  body)
         :immediate-finish t))

(defun my/workout--measure-template ()
  "Capture template text for a measurement entry."
  (concat "* Measurements :measure:\n:PROPERTIES:\n"
          (mapconcat (lambda (m) (format ":%s: %%^{%s}\n" (car m) (cdr m)))
                     my/workout-measures "")
          ":END:\n\n%U"))

(setq org-capture-templates
      (append
       ;; Drop earlier copies, so re-evaluating this section is harmless
       (seq-remove (lambda (tpl) (string-prefix-p "w" (car tpl)))
                   org-capture-templates)
       (list
        '("w" "Workout")
        (my/workout--entry "w1" "Strength 1" "strength-1"
                           "\n%(my/workout-table \"strength-1\")" t)
        (my/workout--entry "w2" "Strength 2" "strength-2"
                           "\n%(my/workout-table \"strength-2\")" t)
        (my/workout--entry "wb" "Boxing" "boxing"
                           "%(my/workout-boxing-body)")
        (my/workout--entry "ws" "Second session" "second"
                           (concat "- Theme, coach remarks ::"
                                   "%(my/workout-last-remarks)\n"
                                   "- Notes :: "))
        `("wm" "Measurements" entry
          (function my/workout--measure-target)
          ,(my/workout--measure-template)
          :immediate-finish t :jump-to-captured t))))

;; --- Commands and keys ----------------------------

(defun my/workout-journal (&optional pick)
  "Open this year's journal. With PICK (C-u), choose any year."
  (interactive "P")
  (find-file
   (if pick
       (read-file-name "Journal: " (file-name-as-directory my/workout-journal-dir)
                       nil t)
     (my/workout--journal (nth 5 (decode-time))))))

(defun my/workout-program (&optional pick)
  "Open the program in force today. With PICK (C-u), choose any."
  (interactive "P")
  (let ((active (cdr (my/workout--program))))
    (cond (pick (find-file (read-file-name
                            "Program: "
                            (file-name-as-directory my/workout-program-dir)
                            nil t)))
          (active (find-file active))
          (t (user-error "No program starting today or earlier in %s"
                         my/workout-program-dir)))))

(defun my/workout-new-program (start)
  "Copy the newest program into a new file starting on START, open it."
  (interactive (list (org-read-date nil nil nil "First day (a Monday): ")))
  (let ((newest (cdr (car (last (my/workout--programs)))))
        (file (expand-file-name (format "program-%s.org" start)
                                my/workout-program-dir)))
    (make-directory my/workout-program-dir t)
    (when (file-exists-p file)
      (user-error "%s already exists" (file-name-nondirectory file)))
    (if newest
        (copy-file newest file)
      (write-region "#+title: Training program\n#+deload_every: 5\n" nil file))
    (find-file file)))

(global-set-key (kbd "C-c w l") #'my/workout-journal)
(global-set-key (kbd "C-c w p") #'my/workout-program)
(global-set-key (kbd "C-c w n") #'my/workout-new-program)
(global-set-key (kbd "C-c w h") #'my/workout-history)
(global-set-key (kbd "C-c w s") #'my/workout-sessions)
(global-set-key (kbd "C-c w m") #'my/workout-measurements)
(global-set-key (kbd "C-c w r") #'my/workout-refresh-last)

;;; init.el ends here
