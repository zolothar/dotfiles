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
      org-agenda-skip-scheduled-if-done t
      org-agenda-skip-deadline-if-done t
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

;;; init.el ends here
