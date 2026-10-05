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
;;   19. Shift log

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

;; --- Knowledge vocabulary -------------------------
;; A knowledge note is described by properties in its file drawer:
;;   TYPE    knowledge
;;   DOMAIN  what it is about, one value from `my/org-knowledge-domains'
;;   TOPICS  specifics inside the domain, free, space-separated:
;;           "sql postgres", "s7-400 profibus", "footwork"
;;   KIND    its form, one value from `my/org-knowledge-kinds'
;; DOMAIN is not AREA: AREA says where time goes, DOMAIN what a note
;; is about. Both lists show their hints in the minibuffer while
;; picking; edit the hints freely, they are only for reading.

(defvar my/org-knowledge-kinds
  '(("concept"         "Понятия"
     "что это и почему так устроено; перечитываю, чтобы понять")
    ("howto"           "Инструкции"
     "шаги к конкретному результату; выполняю по порядку")
    ("reference"       "Справочник"
     "синтаксис, таблицы, флаги; ищу глазами нужную строку")
    ("troubleshooting" "Разбор проблем"
     "симптом, причина, решение; что сломалось и как чинил")
    ("source"          "Источники"
     "конспект одной книги, курса, статьи, видео")
    ("hub"             "Хабы"
     "входная точка в область: пара абзацев и список ссылок"))
  "Knowledge note forms as (NAME LABEL HINT), in display order.
LABEL heads a group in a hub's index.")

(defvar my/org-knowledge-domains
  '(("it" "IT: разработка"
     ("python"         "Python"
      "язык: синтаксис, стандартная библиотека, идиомы, пакеты, venv")
     ("shell"          "Shell"
      "bash, скрипты, конвейеры, CLI-утилиты: grep, sed, awk, find")
     ("cs"             "Основы CS"
      "алгоритмы, структуры данных, сложность, конкурентность")
     ("db"             "Базы данных"
      "модель данных, SQL, ключи, индексы, транзакции, СУБД, NoSQL")
     ("backend"        "Backend"
      "HTTP API, REST, фреймворки, аутентификация, кеш, очереди")
     ("architecture"   "Архитектура"
      "системный дизайн, распределённые системы, масштабирование")
     ("testing"        "Тестирование"
      "pytest, фикстуры, моки, интеграционные тесты, TDD")
     ("devtools"       "Инструменты разработки"
      "git, отладка, профилирование, линтеры, форматтеры")
     ("emacs"          "Emacs"
      "конфиг, пакеты, Org, org-roam, elisp"))
    ("infra" "IT: инфраструктура"
     ("linux"          "Linux"
      "процессы, файлы, права, пользователи, systemd, пакеты, загрузка")
     ("net"            "Сети"
      "TCP/IP, DNS, HTTP, TLS, маршрутизация, VLAN, файрвол")
     ("security"       "Безопасность"
      "криптография, доступ, харденинг, уязвимости, ИБ АСУ ТП, IEC 62443")
     ("virtualization" "Виртуализация"
      "гипервизоры, VM, Proxmox, VMware, снапшоты")
     ("containers"     "Контейнеры"
      "Docker, образы, compose, тома, реестры")
     ("k8s"            "Kubernetes"
      "оркестрация: поды, сервисы, деплойменты, Helm")
     ("cicd"           "CI/CD"
      "пайплайны, сборка, выкладка, GitLab CI, GitHub Actions")
     ("iac"            "Инфраструктура как код"
      "Ansible, Terraform, управление конфигурацией")
     ("cloud"          "Облака"
      "AWS, Azure, Yandex Cloud: сервисы, сети, IAM")
     ("observability"  "Наблюдаемость"
      "логи, метрики, трейсинг, алерты, Prometheus, Grafana"))
    ("automation" "Автоматизация"
     ("plc"            "ПЛК: аппаратура"
      "CPU, модули, ET 200, конфигурация железа, резервирование, диагностика")
     ("plcprog"        "ПЛК: программирование"
      "IEC 61131-3: LAD, FBD, SCL, STL; OB, FB, DB; STEP 7, TIA Portal")
     ("dcs"            "РСУ / PCS 7"
      "мультипроект, CFC, SFC, APL, AS/OS, серверы и клиенты")
     ("scada"          "SCADA / HMI"
      "WinCC, мнемосхемы, тревоги, архивы, отчёты, пользователи")
     ("fieldbus"       "Промышленные сети"
      "Profibus, Profinet, Modbus, OPC UA, шлюзы, диагностика обмена")
     ("control"        "Теория управления"
      "ПИД, настройка контуров, каскадное и прочее регулирование")
     ("instruments"    "КИПиА"
      "датчики, 4–20 мА, HART, клапаны, позиционеры, калибровка")
     ("drives"         "Электропривод"
      "ЧРП, двигатели, пускатели, защиты привода")
     ("electrical"     "Электрика"
      "схемы, питание 24 В, защита, заземление, шкафы")
     ("sis"            "Функциональная безопасность"
      "ПАЗ, SIL, F-системы, блокировки")
     ("process"        "Технология объекта"
      "как устроен сам процесс: оборудование, режимы, электрофильтры")
     ("commissioning"  "Пусконаладка"
      "ПНР, FAT/SAT, испытания, ввод в эксплуатацию")
     ("standards"      "Нормы и документация"
      "ГОСТ, МЭК, P&ID, схемы, проектная документация"))
    ("sport" "Спорт"
     ("boxing"         "Бокс"
      "техника, тактика, комбинации, спарринг")
     ("strength"       "Силовая"
      "упражнения, программы, прогрессия нагрузки")
     ("conditioning"   "ОФП и выносливость"
      "кардио, интервалы, функциональная подготовка")
     ("mobility"       "Мобильность"
      "разминка, растяжка, подвижность суставов")
     ("recovery"       "Восстановление"
      "сон, отдых, травмы и их профилактика")
     ("nutrition"      "Питание"
      "рацион, белок, вес, режим"))
    ("life" "Быт"
     ("health"         "Здоровье"
      "врачи, обследования, профилактика")
     ("finance"        "Финансы"
      "бюджет, налоги, вклады, инвестиции")
     ("home"           "Дом"
      "ремонт, техника, обслуживание")
     ("cooking"        "Кухня"
      "рецепты, техники готовки")
     ("admin"          "Документы"
      "бюрократия, договоры, госуслуги")
     ("travel"         "Поездки"
      "маршруты, транспорт, сборы"))
    ("mind" "Мышление и обучение"
     ("pkm"            "PKM"
      "ведение заметок, базы знаний, продуктивность")
     ("learning"       "Обучение"
      "как учиться, запоминать, планировать учёбу")
     ("languages"      "Языки"
      "иностранные языки: грамматика, лексика"))
    ("culture" "Культура"
     ("books"          "Книги"
      "художественная и нон-фикшн литература")
     ("screen"         "Кино и сериалы"
      "фильмы, сериалы")
     ("games"          "Игры"
      "видеоигры и настольные")))
  "Knowledge domains, grouped: (GROUP LABEL (NAME LABEL HINT)...).
NAME goes into DOMAIN and must be unique across all groups. LABEL of
a domain titles its hub; LABEL of a group heads it in the minibuffer
and titles the group hub.")

(defun my/org-knowledge--domain (name)
  "(GROUP NAME LABEL HINT) for domain NAME, nil when it is unknown."
  (seq-some (lambda (group)
              (when-let ((domain (assoc name (cddr group))))
                (cons (car group) domain)))
            my/org-knowledge-domains))

(defun my/org-knowledge--domain-names ()
  "Every domain name, in the order of `my/org-knowledge-domains'."
  (mapcan (lambda (group) (mapcar #'car (cddr group)))
          my/org-knowledge-domains))

;; Type to its subdirectory. Plural for projects, singular elsewhere.
(defvar my/org-type-dirs
  '(("project"   . "projects")
    ("knowledge" . "knowledge")
    ("calendar"  . "calendar"))
  "Map a document type to its subdirectory under `my/org-dir'.")

;; Projects are split one level further, by area:
;;   projects/<area>/<name>/<name>.org + <name>/attachments/
;; Knowledge is flat and classified by tags, not folders:
;;   knowledge/<name>.org              + attachments/<name>/
;; Areas say where time goes; a knowledge note is about a subject,
;; which often spans several areas. Hub notes (KIND hub) give the
;; structure that folders used to give.
(defvar my/org-area-split-dirs '("projects")
  "Type directories that get an area subdirectory.")

(defvar my/org-dir (expand-file-name "~/org")
  "Root of all Org content.")

(dolist (dir (append (mapcar #'cdr my/org-type-dirs)
                     '("archive" "templates")))
  (make-directory (expand-file-name dir my/org-dir) t))

(dolist (dir my/org-area-split-dirs)
  (dolist (area my/org-areas)
    (make-directory (expand-file-name (concat dir "/" area) my/org-dir) t)))

;; --- Area prompt ----------------------------------
;; Shared by org-capture (section 10) and org-roam (section 14).
;; Ask once per capture and reuse the answer everywhere in a template:
;; in the path, the property, the category and the tag.
(defvar my/org-area-choice nil)

(defun my/org-pick-area ()
  "Return the area for the capture in progress, asking once."
  (or my/org-area-choice
      (setq my/org-area-choice
            (completing-read "Area: " my/org-areas nil t))))

(add-hook 'org-capture-after-finalize-hook
          (lambda () (setq my/org-area-choice nil)))

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
        ("STATUS_ALL" . "idea active paused done archived")
        ("DOMAIN_ALL" . ,(string-join (my/org-knowledge--domain-names) " "))
        ("KIND_ALL"   . ,(mapconcat #'car my/org-knowledge-kinds " "))))

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

;; --- Daily note paths -----------------------------
;; One file per day: calendar/<YYYY>/<MM>/<YYYY-MM-DD>.org. Anything
;; else under calendar/, such as events.org, is an ordinary calendar
;; file and is always in the agenda.

(defvar my/org-calendar-dir (expand-file-name "calendar" my/org-dir)
  "Daily notes and other calendar files.")

(defvar my/org-template-dir (expand-file-name "templates" my/org-dir)
  "Day templates and, under checklists/, checklist templates.
Not scanned by the agenda, excluded from org-roam.")

(defconst my/org-day-file-regexp
  "\\`\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)\\.org\\'"
  "File name of a daily note; group 1 is its date.")

(defun my/org-date+ (time n)
  "Return TIME shifted by N days. Uses decoded time, so DST-safe."
  (let ((d (decode-time time)))
    (setf (decoded-time-day d) (+ (decoded-time-day d) n))
    (encode-time d)))

(defun my/org-monday-of (time)
  "Return the Monday of the week containing TIME."
  (let ((dow (decoded-time-weekday (decode-time time))))
    (my/org-date+ time (- (mod (- dow 1) 7)))))

(defun my/org-day--stamp (date)
  "DATE as \"2026-10-05 Mon\", in English whatever the locale."
  (let ((system-time-locale "C"))
    (format-time-string "%Y-%m-%d %a" date)))

(defun my/org-day-file (date)
  "Daily note file for DATE."
  (expand-file-name (format-time-string "%Y/%m/%Y-%m-%d.org" date)
                    my/org-calendar-dir))

(defun my/org-day--date-of (file)
  "Date of daily note FILE as YYYY-MM-DD; nil for any other file."
  (let ((name (file-name-nondirectory file)))
    (when (string-match my/org-day-file-regexp name)
      (match-string 1 name))))

(defun my/org-day--files ()
  "Every daily note, oldest first."
  (sort (seq-filter #'my/org-day--date-of
                    (directory-files-recursively my/org-calendar-dir "\\.org\\'"))
        (lambda (a b)
          (string< (my/org-day--date-of a) (my/org-day--date-of b)))))

;; --- Which files the agenda scans -----------------
;; Projects, calendar files and daily notes. A daily note older than
;; `my/org-day-agenda-days' drops out, unless it still holds an open
;; task: a task captured into a day is never lost, and the agenda does
;; not slow down as the years of notes pile up. Knowledge files hold
;; no scheduled items and are not scanned; org-roam still indexes
;; everything (section 14).

(defvar my/org-agenda-exclude-regexp "/shift-log/reports/"
  "Files under projects/ the agenda skips: copies of entries kept elsewhere.")

(defvar my/org-day-agenda-days 60
  "Daily notes this many days old or newer are always in the agenda.")

(defun my/org--open-todo-regexp ()
  "Regexp matching a heading with a not-done TODO keyword.
Called at startup too, before Org is loaded and before the keywords
are set further down (TODO states): Org's default stands in then."
  (let* ((seq (cdar (or (bound-and-true-p org-todo-keywords)
                        '((sequence "TODO" "DONE")))))
         (open (if (member "|" seq)
                   (seq-take-while (lambda (k) (not (equal k "|"))) seq)
                 (butlast seq))))
    (concat "^\\*+ "
            (regexp-opt (mapcar (lambda (k) (replace-regexp-in-string "(.*" "" k))
                                open)
                        t)
            "\\b")))

(defun my/org-agenda-files ()
  "Rebuild the agenda file list from disk."
  (let ((since (format-time-string
                "%Y-%m-%d"
                (my/org-date+ (current-time) (- my/org-day-agenda-days))))
        (open (my/org--open-todo-regexp)))
    (append
     (seq-remove (lambda (file) (string-match-p my/org-agenda-exclude-regexp file))
                 (directory-files-recursively
                  (expand-file-name "projects" my/org-dir) "\\.org\\'"))
     (seq-remove #'my/org-day--date-of
                 (directory-files-recursively my/org-calendar-dir "\\.org\\'"))
     (seq-filter (lambda (file)
                   (or (not (string< (my/org-day--date-of file) since))
                       (with-temp-buffer
                         (insert-file-contents file)
                         (let ((case-fold-search nil))
                           (re-search-forward open nil t)))))
                 (my/org-day--files)))))

(setq org-agenda-files (my/org-agenda-files))

(defun my/org-agenda-refresh-files ()
  "Pick up newly created project or calendar files."
  (interactive)
  (setq org-agenda-files (my/org-agenda-files))
  (message "Agenda files: %d" (length org-agenda-files)))

;; --- Capture --------------------------------------
;; Everything quick lands in today's daily note, under Notes. Refile
;; tasks to their projects with C-c C-w; the ones left in daily notes
;; are listed by C-c a i and stay in the agenda until done.
;; %(my/org-pick-area) asks for the area once and reuses the answer.

(setq org-capture-templates
      '(("t" "Task" entry
         (function my/org-day-goto-notes)
         "* TODO %?\n%a")

        ("s" "Scheduled task" entry
         (function my/org-day-goto-notes)
         "* TODO %? :%(my/org-pick-area):\nSCHEDULED: %^{When}T")

        ("n" "Note" entry
         (function my/org-day-goto-notes)
         "* %<%H:%M> %?")

        ("l" "Link with note" entry
         (function my/org-day-goto-notes)
         "* %<%H:%M> %?\n%i\n%a")

        ("k" "Checklist" entry
         (function my/org-day-goto-notes)
         "* %(my/checklist-capture)")

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
  ;; items: tasks without an hour, deadlines, tasks in daily notes.
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
          (:name "Daily notes" :file-path "/calendar/" :order 30)))
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

        ("i" "Tasks in daily notes" alltodo ""
         ((org-agenda-files (seq-filter #'my/org-day--date-of
                                        (my/org-agenda-files)))
          (org-agenda-overriding-header "Tasks in daily notes, to refile")))

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
;; reads it, so new projects and daily notes appear without a
;; restart: the agenda and org-timeblock.
(defun my/org-agenda-files-refresh (&rest _)
  "Rebuild `org-agenda-files' from disk."
  (setq org-agenda-files (my/org-agenda-files)))

(advice-add 'org-agenda :before #'my/org-agenda-files-refresh)
(with-eval-after-load 'org-timeblock
  (advice-add 'org-timeblock :before #'my/org-agenda-files-refresh))

;; --- Checklists -----------------------------------
;;
;;   templates/checklists/<name>.org   one checklist template per file
;;
;; A template is a #+title and "- [ ]" items, nested if you like.
;; Headings in it are allowed: they are shifted to wherever the list
;; lands. A new file is a new checklist; C-c K opens one by name and
;; starts a new one when the name is unknown. A list is put to use:
;;   C-c c k              into today's daily note, under Notes
;;   C-c k                as the last child of the heading at point,
;;                        in any Org file; with C-u, the bare items
;;                        at point, e.g. inside a block
;;   #+checklist: NAME    in a block of a day template, filled in
;;                        when the day is generated
;; The first two give a heading "Title [0/N] :checklist:". Each use
;; is a copy: editing a template changes lists inserted afterwards,
;; never earlier ones, so a ticked list stays a record of that day.

(defvar my/checklist-dir (expand-file-name "checklists" my/org-template-dir)
  "Checklist templates, one per file, named <name>.org.")

(make-directory my/checklist-dir t)

(defun my/checklist-names ()
  "Every checklist template name."
  (mapcar #'file-name-base (directory-files my/checklist-dir nil "\\.org\\'")))

(defun my/checklist--file (name)
  "File of checklist template NAME."
  (expand-file-name (concat name ".org") my/checklist-dir))

(defun my/checklist--read (name)
  "(TITLE . ITEMS) of checklist NAME, nil when there is no such file.
ITEMS is everything after the #+keywords at the top, trimmed."
  (let ((file (my/checklist--file name)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (let ((title (when (re-search-forward "^#\\+title:[ \t]*\\(.+\\)$" nil t)
                       (string-trim (match-string 1)))))
          (goto-char (point-min))
          (while (and (not (eobp)) (looking-at-p "^\\(#\\+\\|[ \t]*$\\)"))
            (forward-line 1))
          (cons (or title name)
                (string-trim (buffer-substring-no-properties
                              (point) (point-max)))))))))

(defun my/checklist--shift (text level)
  "TEXT with its headings shifted so that the highest is at LEVEL."
  (let ((levels '())
        (start 0))
    (while (string-match "^\\(\\*+\\) " text start)
      (push (length (match-string 1 text)) levels)
      (setq start (match-end 0)))
    (if (null levels)
        text
      (let ((shift (- level (apply #'min levels))))
        (replace-regexp-in-string
         "^\\(\\*+\\) "
         (lambda (m)
           (concat (make-string (max 1 (+ (length (match-string 1 m)) shift)) ?*)
                   " "))
         text t t)))))

(defun my/checklist-items (name level)
  "Items of checklist NAME to go under a heading at LEVEL, or nil."
  (when-let ((checklist (my/checklist--read name)))
    (my/checklist--shift (cdr checklist) (1+ level))))

(defun my/checklist--entry (name level)
  "Checklist NAME as an entry at LEVEL: titled, tagged, counted."
  (let ((checklist (or (my/checklist--read name)
                       (user-error "No checklist %s" name))))
    (with-temp-buffer
      (delay-mode-hooks (org-mode))
      (insert (make-string level ?*) " " (car checklist) " [/] :checklist:\n"
              (my/checklist--shift (cdr checklist) (1+ level)) "\n")
      (org-update-statistics-cookies 'all)
      (buffer-string))))

(defun my/checklist-read-name (&optional prompt new-ok)
  "Ask for a checklist name, titles shown alongside.
With NEW-OK, a name that does not exist yet is accepted."
  (let ((names (my/checklist-names)))
    (completing-read
     (or prompt "Checklist: ")
     (my/org--annotated-table                 ; section 14
      names
      (mapcar (lambda (name) (cons name (car (my/checklist--read name)))) names))
     nil (not new-ok))))

(defun my/checklist-capture ()
  "Ask for a checklist; return its entry for a capture template.
The leading \"* \" is left to the template."
  (substring (my/checklist--entry (my/checklist-read-name) 1) 2))

(defun my/checklist-insert (name &optional bare)
  "Insert checklist NAME as the last child of the heading at point.
Before the first heading it goes at the end of the file, at level 1.
With BARE (\\[universal-argument]), insert only the items, at point."
  (interactive (list (my/checklist-read-name) current-prefix-arg))
  (unless (derived-mode-p 'org-mode)
    (user-error "Not an Org buffer"))
  (if bare
      (let ((items (or (my/checklist-items name (or (org-current-level) 0))
                       (user-error "No checklist %s" name))))
        (unless (bolp) (insert "\n"))
        (insert items "\n")
        (org-update-statistics-cookies nil))
    (let ((level (if (org-before-first-heading-p)
                     (progn (goto-char (point-max)) 1)
                   (prog1 (1+ (org-current-level))
                     (org-end-of-subtree t t)))))
      (unless (bolp) (insert "\n"))
      (save-excursion (insert (my/checklist--entry name level)))
      (org-fold-show-subtree))))

(defun my/checklist-edit (name)
  "Open checklist template NAME. An unknown NAME starts a new template."
  (interactive (list (my/checklist-read-name
                      "Checklist (a new name starts one): " t)))
  (find-file (my/checklist--file name))
  (when (= (buffer-size) 0)
    (insert "#+title: " (read-string "Title: ") "\n\n- [ ] ")))

(global-set-key (kbd "C-c k") #'my/checklist-insert)
(global-set-key (kbd "C-c K") #'my/checklist-edit)

;; --- Daily notes ----------------------------------
;;
;;   calendar/<YYYY>/<MM>/<YYYY-MM-DD>.org
;;
;; A daily note is an org-roam node (TYPE calendar), titled with its
;; date, so a note can link to a day and a day shows its backlinks.
;; It has two top-level headings:
;;   Schedule  time blocks, generated from a day template; the only
;;             part the generator ever rewrites
;;   Notes     yours: quick notes, tasks and checklists from capture
;;
;;   C-c j j  today          C-c j n / C-c j p  next / previous note
;;   C-c j d  any date       C-c j g            schedule for a day
;;   C-c j w  schedule for a week, C-c j W for several weeks
;;
;; A note is created as soon as it is opened or captured into.

(defun my/org-day--skeleton (date)
  "Text of a new daily note for DATE."
  (concat ":PROPERTIES:\n"
          ":ID:       " (org-id-new) "\n"
          ":TYPE:     calendar\n"
          ":END:\n"
          "#+title: " (my/org-day--stamp date) "\n\n"
          "* Schedule\n"
          "* Notes\n"))

(defun my/org-day--buffer (date)
  "Buffer visiting DATE's daily note, which is created when missing."
  (let ((file (my/org-day-file date)))
    (make-directory (file-name-directory file) t)
    (with-current-buffer (find-file-noselect file)
      (when (= (buffer-size) 0)
        (insert (my/org-day--skeleton date))
        (save-buffer))
      (current-buffer))))

(defun my/org-day--heading (name)
  "Position of top-level heading NAME in this buffer, nil if absent."
  (save-excursion
    (goto-char (point-min))
    (let ((case-fold-search nil))
      (when (re-search-forward
             (format "^\\* %s\\(?:[ \t]\\|$\\)" (regexp-quote name)) nil t)
        (match-beginning 0)))))

(defun my/org-day-goto-notes ()
  "Capture target: the Notes heading of today's daily note."
  (set-buffer (my/org-day--buffer (current-time)))
  (widen)
  (goto-char (or (my/org-day--heading "Notes")
                 (progn (goto-char (point-max))
                        (unless (bolp) (insert "\n"))
                        (save-excursion (insert "* Notes\n"))
                        (point)))))

(defun my/org-day-visit (date)
  "Open DATE's daily note."
  (pop-to-buffer-same-window (my/org-day--buffer date)))

(defun my/org-day-today ()
  "Open today's daily note."
  (interactive)
  (my/org-day-visit (current-time)))

(defun my/org-day-goto (date)
  "Open the daily note of DATE, picked in the calendar."
  (interactive (list (org-read-date nil t nil "Day: ")))
  (my/org-day-visit date))

(defun my/org-day--neighbour (n)
  "Open the existing daily note N notes after this one, before if N < 0.
Outside a daily note, count from today."
  (let* ((here (or (and buffer-file-name (my/org-day--date-of buffer-file-name))
                   (format-time-string "%Y-%m-%d")))
         (files (my/org-day--files))
         (side (if (> n 0)
                   (seq-filter (lambda (f) (string< here (my/org-day--date-of f)))
                               files)
                 (reverse (seq-filter (lambda (f) (string< (my/org-day--date-of f) here))
                                      files))))
         (file (nth (1- (abs n)) side)))
    (if file
        (find-file file)
      (user-error "No %s daily note" (if (> n 0) "later" "earlier")))))

(defun my/org-day-next (n)
  "Open the next existing daily note, or the N-th one."
  (interactive "p")
  (my/org-day--neighbour n))

(defun my/org-day-previous (n)
  "Open the previous existing daily note, or the N-th one back."
  (interactive "p")
  (my/org-day--neighbour (- n)))

;; --- Schedules from day templates -----------------
;;
;;   templates/<name>-template.org  one day per file, any fixed date inside
;;   my/org-week-plan               default template for each weekday
;;
;; A template is a flat chronological list: a heading, one area tag, one
;; timestamp, optionally a body. The generator moves the timestamps to
;; the target date, derives each block's CATEGORY from its area tag and
;; puts the blocks under the day's Schedule, recording the template's
;; name in its TEMPLATE property. Generated blocks carry no repeaters,
;; so any single block can be deleted, moved or stretched without
;; touching other days. A "#+checklist: NAME" line in a block's body
;; becomes the items of that checklist; a "[/]" cookie in the block's
;; heading counts them.
;;
;; Every template covers its own calendar day only. A night shift is
;; split at midnight: shift-night runs to 23:59, and shift-recovery
;; opens with the rest of it, 00:00 to the morning briefing.

(defvar my/org-week-plan
  '((1 . "monday-template")
    (2 . "tuesday-template")
    (3 . "wednesday-template")
    (4 . "thursday-template")
    (5 . "friday-template")
    (6 . "saturday-template")
    (0 . "sunday-template"))
  "Weekday number (0 = Sunday) to a template name in `my/org-template-dir'.
Several weekdays may point at the same template. Templates not listed
here are still offered by `my/org-day-generate'.")

(defun my/org-templates ()
  "Template names: those of `my/org-week-plan' in weekday order, then the rest."
  (let ((files (mapcar #'file-name-base
                       (directory-files my/org-template-dir nil
                                        "-template\\.org\\'"))))
    (append (seq-filter (lambda (name) (member name files))
                        (delete-dups (mapcar #'cdr my/org-week-plan)))
            (seq-remove (lambda (name) (rassoc name my/org-week-plan))
                        files))))

(defun my/org-template--title (name)
  "The #+title of template NAME, or nil."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name (concat name ".org") my/org-template-dir) nil 0 1000)
    (when (re-search-forward "^#\\+title:[ \t]*\\(.+\\)$" nil t)
      (match-string 1))))

(defun my/org-day--default-template (date)
  "The template `my/org-week-plan' gives DATE's weekday, or nil."
  (cdr (assq (decoded-time-weekday (decode-time date)) my/org-week-plan)))

(defun my/org-read-template (date)
  "Ask for a template for DATE. Its weekday's template is the default."
  (let ((names (my/org-templates)))
    (completing-read
     (format "Template for %s: " (my/org-day--stamp date))
     (my/org--annotated-table               ; section 14
      names
      (mapcar (lambda (name) (cons name (my/org-template--title name))) names))
     nil t nil nil (my/org-day--default-template date))))

(defun my/org-blocks--render (template date)
  "Return TEMPLATE's blocks moved to DATE, or nil if TEMPLATE is missing."
  (let ((file (expand-file-name (concat template ".org") my/org-template-dir))
        (stamp (my/org-day--stamp date)))
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
        ;; Checklists in place of their #+checklist: lines. Blocks are
        ;; level 1 here, so headings inside a list start at level 2.
        (goto-char (point-min))
        (while (re-search-forward
                "^[ \t]*#\\+checklist:[ \t]*\\(\\S-+\\)[ \t]*$" nil t)
          (let* ((name (match-string 1))
                 (items (save-match-data (my/checklist-items name 1))))
            (replace-match (or items (format "No checklist: %s" name)) t t)))
        ;; CATEGORY from the area tag, [0/6] in place of [/]
        (delay-mode-hooks (org-mode))
        (org-update-statistics-cookies 'all)
        (org-map-entries
         (lambda ()
           (when-let ((area (seq-find (lambda (tag) (member tag my/org-areas))
                                      (org-get-tags nil t))))
             (org-set-property "CATEGORY" area))))
        ;; Demote by one level to nest under Schedule
        (goto-char (point-min))
        (while (re-search-forward "^\\*" nil t)
          (replace-match "**"))
        (buffer-string)))))

(defun my/org-day--schedule (date template)
  "The Schedule heading of DATE with TEMPLATE's blocks under it, as text."
  (let ((body (and template (my/org-blocks--render template date))))
    (concat "* Schedule\n"
            (if template
                (format ":PROPERTIES:\n:TEMPLATE: %s\n:END:\n" template)
              "")
            (cond (body (let ((text (string-trim-right body)))
                          (if (string-empty-p text) "" (concat text "\n"))))
                  (template (format "No template: %s\n" template))
                  (t "")))))

(defun my/org-day--planned-p (date)
  "Non-nil when DATE's daily note has blocks under its Schedule."
  (let ((file (my/org-day-file date)))
    (and (file-exists-p file)
         (with-temp-buffer
           (insert-file-contents file)
           (let ((case-fold-search nil))
             (and (re-search-forward "^\\* Schedule\\(?:[ \t]\\|$\\)" nil t)
                  (re-search-forward "^\\*\\{1,2\\} " nil t)
                  (string= (match-string 0) "** ")))))))

(defun my/org-day--put (date template &optional replace)
  "Fill the Schedule of DATE's daily note from TEMPLATE and save it.
Only Schedule is touched. One that already has blocks is replaced
when REPLACE is `yes', after a question when REPLACE is nil, and
kept otherwise. Return the position of the Schedule heading."
  (with-current-buffer (my/org-day--buffer date)
    (prog1
        (org-with-wide-buffer
         (let ((pos (my/org-day--heading "Schedule")))
           (if pos
               (goto-char pos)
             ;; No Schedule: in front of the first heading, else at the end
             (goto-char (point-min))
             (if (re-search-forward "^\\* " nil t)
                 (goto-char (match-beginning 0))
               (goto-char (point-max))
               (unless (bolp) (insert "\n")))
             (save-excursion (insert "* Schedule\n"))))
         (let* ((end (save-excursion
                       (forward-line 1)
                       (if (re-search-forward "^\\* " nil t)
                           (match-beginning 0)
                         (point-max))))
                (filled (save-excursion
                          (forward-line 1)
                          (re-search-forward "^\\*\\* " end t))))
           (when (or (not filled)
                     (eq replace 'yes)
                     (and (null replace)
                          (y-or-n-p
                           (format "%s already planned (%s), replace? "
                                   (my/org-day--stamp date)
                                   (or (org-entry-get (point) "TEMPLATE")
                                       "by hand")))))
             (delete-region (point) end)
             (save-excursion (insert (my/org-day--schedule date template)))))
         (point))
      (save-buffer))))

(defun my/org-day-generate (date template)
  "Fill DATE's Schedule from TEMPLATE and open the daily note there.
Interactively, asks for the date, then for the template."
  (interactive
   (let ((date (org-read-date nil t nil "Day: ")))
     (list date (my/org-read-template date))))
  (let ((pos (my/org-day--put date template)))
    (my/org-agenda-files-refresh)
    (my/org-day-visit date)
    (widen)
    (goto-char pos)
    (org-fold-show-subtree)
    (recenter 0)))

(defun my/org-week--fill (start)
  "Fill every day of the week containing START from `my/org-week-plan'.
Days already planned are replaced or kept after one question. Notes
opened only for this are closed again. Return the week's Monday."
  (let* ((monday (my/org-monday-of start))
         (days (mapcar (lambda (n) (my/org-date+ monday n)) (number-sequence 0 6)))
         (planned (seq-count #'my/org-day--planned-p days))
         (replace (if (or (zerop planned)
                          (y-or-n-p
                           (format "Week of %s: %d day(s) already planned, replace them? "
                                   (format-time-string "%Y-%m-%d" monday) planned)))
                      'yes
                    'no))
         (before (buffer-list)))
    (dolist (date days)
      (my/org-day--put date (my/org-day--default-template date) replace))
    (dolist (buffer (buffer-list))
      (unless (or (memq buffer before) (buffer-modified-p buffer))
        (kill-buffer buffer)))
    monday))

(defun my/org-week-generate (start)
  "Fill the week containing START from day templates, open its Monday."
  (interactive (list (org-read-date nil t nil "Any day of the week")))
  (let ((monday (my/org-week--fill start)))
    (my/org-agenda-files-refresh)
    (my/org-day-visit monday)))

(defun my/org-weeks-generate (start count)
  "Fill COUNT consecutive weeks, the first one containing START."
  (interactive (list (org-read-date nil t nil "Any day of the first week")
                     (read-number "Weeks: " 4)))
  (dotimes (i count)
    (my/org-week--fill (my/org-date+ start (* 7 i))))
  (my/org-agenda-files-refresh)
  (message "Generated %d week(s)" count))

(global-set-key (kbd "C-c j j") #'my/org-day-today)
(global-set-key (kbd "C-c j d") #'my/org-day-goto)
(global-set-key (kbd "C-c j n") #'my/org-day-next)
(global-set-key (kbd "C-c j p") #'my/org-day-previous)
(global-set-key (kbd "C-c j g") #'my/org-day-generate)
(global-set-key (kbd "C-c j w") #'my/org-week-generate)
(global-set-key (kbd "C-c j W") #'my/org-weeks-generate)

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
  ;; Skip archives and templates. Daily notes are indexed: a note can
  ;; link to a day, and a day lists what links to it.
  (org-roam-file-exclude-regexp
   '("/archive/" "/templates/" "/attachments/" "/\\.git/"))
  :bind (("C-c n f" . org-roam-node-find)
         ("C-c n i" . org-roam-node-insert)
         ("C-c n c" . org-roam-capture)
         ("C-c n l" . org-roam-buffer-toggle)
         ("C-c n g" . org-roam-graph)
         ("C-c n e" . org-roam-extract-subtree)
         ("C-c n s" . org-roam-db-sync)
         ("C-c n t" . org-roam-tag-add)       ; completes over existing tags
         ("C-c n a" . org-roam-alias-add)     ; a second name for the node
         ("C-c n k" . my/org-knowledge-edit)  ; domain, topics, kind of this note
         :map org-mode-map
         ("C-M-i" . completion-at-point))
  :config
  ;; Columns in the selector. They mean the same for every node, each
  ;; kind of node fills them from its own properties:
  ;;   type    TYPE, else the top folder, else the file name
  ;;   place   knowledge: DOMAIN (GROUP for group hubs); else AREA
  ;;   kind    knowledge: KIND; projects: STATUS
  ;;   topics  TOPICS, else tags that do not repeat the above
  ;; A heading with its own ID takes whatever it lacks from its file.
  ;; Orderless matches the whole line: "db howto", "work active".
  (cl-defmethod org-roam-node-type ((node org-roam-node))
    "TYPE of NODE, else its top folder under `org-roam-directory'."
    (or (my/org-roam--prop node "TYPE")
        (let ((parts (split-string (file-relative-name (org-roam-node-file node)
                                                       org-roam-directory)
                                   "/")))
          (if (cdr parts) (car parts) (file-name-base (car parts))))))

  (cl-defmethod org-roam-node-place ((node org-roam-node))
    "DOMAIN or GROUP of a knowledge NODE, AREA of anything else."
    (or (my/org-roam--prop node "DOMAIN")
        (my/org-roam--prop node "GROUP")
        (my/org-roam--prop node "AREA")
        ""))

  (cl-defmethod org-roam-node-kind ((node org-roam-node))
    "KIND of a knowledge NODE, STATUS of a project."
    (or (my/org-roam--prop node "KIND")
        (my/org-roam--prop node "STATUS")
        ""))

  (cl-defmethod org-roam-node-topics ((node org-roam-node))
    "TOPICS of NODE, else its tags minus areas and types."
    (or (my/org-roam--prop node "TOPICS")
        (string-join (seq-remove (lambda (tag) (or (member tag my/org-areas)
                                                   (member tag my/org-types)))
                                 (org-roam-node-tags node))
                     " ")))

  (setq org-roam-node-display-template
      (concat "${type:10} ${place:12} ${kind:15} ${title:56} "
              (propertize "${topics:30}" 'face 'org-tag)))

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

;; --- Node properties ------------------------------

(defun my/org-roam--value (props key)
  "Value of KEY in the property alist PROPS, nil when missing or empty."
  (let ((value (cdr (assoc-string key props t))))
    (unless (or (null value) (string-empty-p value)) value)))

(defun my/org-roam--own-prop (node key)
  "KEY from NODE's own property drawer."
  (my/org-roam--value (org-roam-node-properties node) key))

(defvar my/org-roam--file-props-cache (make-hash-table :test #'equal)
  "File to (MTIME . PROPERTIES) of its file-level node.")

(defun my/org-roam--file-props (node)
  "Properties of the file-level node of NODE's file, cached by mtime."
  (let* ((file (org-roam-node-file node))
         (mtime (org-roam-node-file-mtime node))
         (hit (gethash file my/org-roam--file-props-cache)))
    (if (and hit (equal (car hit) mtime))
        (cdr hit)
      (let ((props (caar (org-roam-db-query
                          [:select properties :from nodes
                           :where (and (= file $s1) (= level 0))]
                          file))))
        (puthash file (cons mtime props) my/org-roam--file-props-cache)
        props))))

(defun my/org-roam--prop (node key)
  "KEY of NODE; a heading node falls back to its file's value."
  (or (my/org-roam--own-prop node key)
      (and (> (org-roam-node-level node) 0)
           (my/org-roam--value (my/org-roam--file-props node) key))))

;; --- Knowledge prompts ----------------------------
;; Asked in this order: domain, topics, kind. Each is asked once per
;; capture, like the area prompt, and the answers are kept until the
;; capture ends: the body and the hub check read them too.

(defun my/org--annotated-table (candidates hints &optional groups)
  "Completion table over CANDIDATES, kept in the given order.
HINTS and GROUPS are alists from a candidate to the grey hint shown
next to it and to the group heading it is listed under."
  (let ((width (+ 2 (apply #'max 0 (mapcar #'length candidates)))))
    (lambda (string pred action)
      (if (eq action 'metadata)
          `(metadata
            (display-sort-function . identity)
            (cycle-sort-function . identity)
            (annotation-function
             . ,(lambda (candidate)
                  (when-let ((hint (cdr (assoc candidate hints))))
                    (concat (make-string (max 1 (- width (length candidate))) ?\s)
                            (propertize hint 'face 'completions-annotations)))))
            ,@(when groups
                `((group-function
                   . ,(lambda (candidate transform)
                        (if transform
                            candidate
                          (cdr (assoc candidate groups))))))))
        (complete-with-action action candidates string pred)))))

(defun my/org-knowledge-read-domain (&optional default)
  "Ask for a domain, grouped and hinted. DEFAULT is taken on empty input."
  (let* ((names (my/org-knowledge--domain-names))
         (info (mapcar #'my/org-knowledge--domain names)))
    (completing-read
     "Domain: "
     (my/org--annotated-table
      names
      (mapcar (lambda (d) (cons (nth 1 d) (format "%s: %s" (nth 2 d) (nth 3 d))))
              info)
      (mapcar (lambda (d) (cons (nth 1 d)
                                (nth 1 (assoc (car d) my/org-knowledge-domains))))
              info))
     nil t nil nil default)))

(defun my/org-knowledge--used-topics ()
  "Every TOPICS value already used in org-roam, sorted."
  (sort (delete-dups
         (mapcan (lambda (row)
                   (when-let ((value (my/org-roam--value (car row) "TOPICS")))
                     (split-string value)))
                 (org-roam-db-query [:select properties :from nodes])))
        #'string<))

(defun my/org-knowledge-read-topics (&optional current)
  "Ask for topics, comma-separated, possibly none.
Return them space-separated; spaces inside a topic become dashes.
CURRENT, a space-separated string, is offered for editing."
  (string-join
   (seq-remove #'string-empty-p
               (mapcar (lambda (topic)
                         (replace-regexp-in-string
                          "[[:space:]]+" "-" (string-trim topic)))
                       (completing-read-multiple
                        "Topics, comma-separated, may be empty: "
                        (my/org-knowledge--used-topics) nil nil
                        (when current (string-join (split-string current) ",")))))
   " "))

(defun my/org-knowledge-read-kind (&optional default)
  "Ask for a note form, hinted. DEFAULT is taken on empty input."
  (completing-read
   "Kind: "
   (my/org--annotated-table
    (mapcar #'car my/org-knowledge-kinds)
    (mapcar (lambda (k) (cons (car k) (nth 2 k))) my/org-knowledge-kinds))
   nil t nil nil default))

(defvar my/org-knowledge--choice nil
  "Answers given in the knowledge capture in progress, as an alist.")

(defun my/org-knowledge--ask (key reader)
  "Answer KEY for this capture, calling READER the first time only."
  (let ((cell (assq key my/org-knowledge--choice)))
    (if cell
        (cdr cell)
      (let ((value (funcall reader)))
        (push (cons key value) my/org-knowledge--choice)
        value))))

(defun my/org-pick-domain () (my/org-knowledge--ask 'domain #'my/org-knowledge-read-domain))
(defun my/org-pick-topics () (my/org-knowledge--ask 'topics #'my/org-knowledge-read-topics))
(defun my/org-pick-kind   () (my/org-knowledge--ask 'kind   #'my/org-knowledge-read-kind))

;; --- Starting body by kind ------------------------

(defvar my/org-knowledge-skeletons
  '(("howto"           . "\n* Задача\n\n* Шаги\n\n* Проверка\n")
    ("troubleshooting" . "\n* Симптом\n\n* Причина\n\n* Решение\n\n* Как проверить\n")
    ("source"          . "\n- Источник :: \n- Автор :: \n\n* Главное\n\n* Конспект\n")
    ("hub"             . "\n#+BEGIN: knowledge-index :domain \"%s\"\n#+END:\n"))
  "Body a new knowledge note starts with, by KIND. %s is the domain.
Kinds missing here start empty.")

(defun my/org-knowledge-body ()
  "Starting body for the knowledge note being captured."
  (let ((skeleton (cdr (assoc (cdr (assq 'kind my/org-knowledge--choice))
                              my/org-knowledge-skeletons))))
    (if skeleton
        (format skeleton (or (cdr (assq 'domain my/org-knowledge--choice)) ""))
      "")))

;; --- Hubs -----------------------------------------
;; Every domain has a hub, knowledge/hub-<domain>.org, and every group
;; a group hub, knowledge/hub-group-<group>.org. They are created the
;; first time a note lands in the domain. Write whatever you like in a
;; hub; the knowledge-index block in it is rebuilt from the org-roam
;; database each time the hub is opened, or with C-c C-c on its
;; #+BEGIN line:
;;   :domain "db"   every note of the domain, grouped by KIND
;;   :group "it"    every domain hub of the group, with note counts

(defun my/org-knowledge--nodes ()
  "Every file-level knowledge node, sorted by title."
  (require 'org-roam)
  (sort (seq-filter (lambda (node)
                      (and (= (org-roam-node-level node) 0)
                           (equal (my/org-roam--own-prop node "TYPE") "knowledge")))
                    (org-roam-node-list))
        (lambda (a b)
          (string-collate-lessp (org-roam-node-title a) (org-roam-node-title b) nil t))))

(defun my/org-knowledge--hub-p (node)
  "Non-nil when NODE is a hub."
  (equal (my/org-roam--own-prop node "KIND") "hub"))

(defun my/org-knowledge--hub (key value)
  "The hub node whose property KEY is VALUE, or nil."
  (seq-find (lambda (node)
              (and (my/org-knowledge--hub-p node)
                   (equal (my/org-roam--own-prop node key) value)))
            (my/org-knowledge--nodes)))

(defun my/org-knowledge--link (node)
  "An id: link to NODE, titled."
  (org-link-make-string (concat "id:" (org-roam-node-id node))
                        (org-roam-node-title node)))

(defun my/org-knowledge--index-domain (domain)
  "Insert the notes of DOMAIN, grouped by KIND."
  (let* ((kinds (mapcar #'car my/org-knowledge-kinds))
         (notes (seq-filter (lambda (node)
                              (and (equal (my/org-roam--own-prop node "DOMAIN") domain)
                                   (not (my/org-knowledge--hub-p node))))
                            (my/org-knowledge--nodes)))
         (sections
          (delq nil
                (mapcar
                 (lambda (kind)
                   (when-let ((these (seq-filter
                                      (lambda (node)
                                        (equal (car (member (my/org-roam--own-prop node "KIND")
                                                            kinds))
                                               (car kind)))
                                      notes)))
                     (concat "*" (nth 1 kind) "*\n"
                             (mapconcat (lambda (node)
                                          (concat "- " (my/org-knowledge--link node)))
                                        these "\n"))))
                 (append my/org-knowledge-kinds '((nil "Без типа")))))))
    (insert (if sections (string-join sections "\n\n") "Пока нет заметок."))))

(defun my/org-knowledge--index-group (group)
  "Insert the domains of GROUP that have a hub or notes, with counts."
  (let* ((nodes (my/org-knowledge--nodes))
         (lines
          (delq nil
                (mapcar
                 (lambda (domain)
                   (let* ((name (car domain))
                          (mine (seq-filter (lambda (node)
                                              (equal (my/org-roam--own-prop node "DOMAIN")
                                                     name))
                                            nodes))
                          (hub (seq-find #'my/org-knowledge--hub-p mine))
                          (count (seq-count (lambda (node)
                                              (not (my/org-knowledge--hub-p node)))
                                            mine)))
                     (when (or hub (> count 0))
                       (format "- %s (%d)"
                               (if hub (my/org-knowledge--link hub) (nth 1 domain))
                               count))))
                 (cddr (assoc group my/org-knowledge-domains))))))
    (insert (if lines (string-join lines "\n") "Пока нет заметок."))))

(defun org-dblock-write:knowledge-index (params)
  "Dynamic block listing knowledge notes. PARAMS: :domain or :group."
  (let ((domain (plist-get params :domain))
        (group (plist-get params :group)))
    (cond (domain (my/org-knowledge--index-domain (format "%s" domain)))
          (group  (my/org-knowledge--index-group (format "%s" group))))))

(defun my/org-knowledge-refresh-index ()
  "Rebuild knowledge-index blocks in this buffer.
The buffer stays unmodified when the lists have not changed."
  (when (and buffer-file-name
             (save-excursion
               (goto-char (point-min))
               (re-search-forward "^[ \t]*#\\+BEGIN: knowledge-index" nil t)))
    (let ((hash (buffer-hash))
          (modified (buffer-modified-p)))
      (with-demoted-errors "knowledge-index: %S"
        (org-update-all-dblocks))
      (when (equal hash (buffer-hash))
        (set-buffer-modified-p modified)))))

(add-hook 'org-mode-hook #'my/org-knowledge-refresh-index)

(defun my/org-knowledge--write-hub (file props title body)
  "Create hub FILE under `my/org-dir' unless it exists. Return its ID.
PROPS is an alist for the file drawer, TITLE and BODY its text."
  (let ((file (expand-file-name file my/org-dir))
        (id (org-id-new)))
    (unless (file-exists-p file)
      (with-temp-file file
        (insert ":PROPERTIES:\n"
                (format ":ID:       %s\n" id)
                (mapconcat (lambda (p) (format ":%-9s %s\n" (concat (car p) ":") (cdr p)))
                           props "")
                ":END:\n"
                "#+title: " title "\n\n"
                body))
      (org-roam-db-update-file file)
      (message "Created hub %s" (file-name-nondirectory file))
      id)))

(defun my/org-knowledge-ensure-hubs (domain &optional group-only)
  "Create DOMAIN's group hub and its own hub when they are missing.
With GROUP-ONLY, skip the domain hub: the note is that hub itself."
  (when-let ((d (my/org-knowledge--domain domain)))
    (let* ((group (car d))
           (group-label (nth 1 (assoc group my/org-knowledge-domains)))
           (group-hub (my/org-knowledge--hub "GROUP" group))
           (group-id (if group-hub
                         (org-roam-node-id group-hub)
                       (my/org-knowledge--write-hub
                        (format "knowledge/hub-group-%s.org" group)
                        `(("TYPE" . "knowledge") ("GROUP" . ,group) ("KIND" . "hub"))
                        group-label
                        (format "#+BEGIN: knowledge-index :group \"%s\"\n#+END:\n"
                                group)))))
      (unless (or group-only (my/org-knowledge--hub "DOMAIN" domain))
        (my/org-knowledge--write-hub
         (format "knowledge/hub-%s.org" domain)
         `(("TYPE" . "knowledge") ("DOMAIN" . ,domain) ("KIND" . "hub"))
         (nth 2 d)
         (concat (if group-id (format "Группа: [[id:%s][%s]]\n\n" group-id group-label) "")
                 (format "#+BEGIN: knowledge-index :domain \"%s\"\n#+END:\n"
                         domain)))))))

(defun my/org-knowledge--after-capture ()
  "Create missing hubs for a finished knowledge capture, then forget it."
  (let ((choice my/org-knowledge--choice))
    (setq my/org-knowledge--choice nil)
    (when (and choice (not org-note-abort))
      (with-demoted-errors "Knowledge hubs: %S"
        (my/org-knowledge-ensure-hubs (cdr (assq 'domain choice))
                                      (equal (cdr (assq 'kind choice)) "hub"))))))

(add-hook 'org-capture-after-finalize-hook #'my/org-knowledge--after-capture)

;; A capture cancelled with C-g during a prompt never finalizes, and
;; its answers would leak into the next capture. Start each one clean.
(defun my/org-capture-forget-answers (&rest _)
  "Drop answers left over from an interrupted capture."
  (setq my/org-knowledge--choice nil
        my/org-area-choice nil))

(advice-add 'org-capture :before #'my/org-capture-forget-answers)

(defun my/org-knowledge-edit ()
  "Ask domain, topics and kind for the note in this buffer and store them.
Current values are the defaults. Works on old notes too: TYPE is set to
knowledge. Missing hubs are created afterwards."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Not an Org buffer"))
  (let* ((pom (point-min))
         (domain (my/org-knowledge-read-domain (org-entry-get pom "DOMAIN")))
         (topics (my/org-knowledge-read-topics (org-entry-get pom "TOPICS")))
         (kind (my/org-knowledge-read-kind (org-entry-get pom "KIND"))))
    (org-entry-put pom "TYPE" "knowledge")
    (org-entry-put pom "DOMAIN" domain)
    (org-entry-put pom "TOPICS" topics)
    (org-entry-put pom "KIND" kind)
    (save-buffer)
    (my/org-knowledge-ensure-hubs domain (equal kind "hub"))))

;; --- Capture templates ----------------------------

(setq org-roam-capture-templates
      '(("k" "knowledge" plain "%?%(my/org-knowledge-body)"
         :target (file+head
                  "knowledge/${title}.org"
                  ":PROPERTIES:\n:TYPE:     knowledge\n:DOMAIN:   %(my/org-pick-domain)\n:TOPICS:   %(my/org-pick-topics)\n:KIND:     %(my/org-pick-kind)\n:END:\n#+title: ${title}\n#+property: DIR attachments/${title}\n")
         :unnarrowed t)

        ("p" "project" plain "%?"
         :target (file+head
                  "projects/%(my/org-pick-area)/${title}/${title}.org"
                  ":PROPERTIES:\n:TYPE: project\n:AREA: %(my/org-pick-area)\n:STATUS: active\n:STARTED: [%<%Y-%m-%d %a>]\n:FINISHED:\n:END:\n#+title: ${title}\n#+category: %(my/org-pick-area)\n#+filetags: :project:%(my/org-pick-area):\n#+property: DIR attachments\n\n* Tasks\n")
         :unnarrowed t)))

;; C-c n e: the extracted subtree becomes a knowledge note. The path is
;; asked for with this as the default, so replace the name with a
;; kebab-case one at the prompt, then describe the note with C-c n k.
(setq org-roam-extract-new-file-path "knowledge/${slug}.org")

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
     ("l" "~/org/templates/checklists/" "Checklists")
     ("w" "~/org/projects/workouts/training/" "Training")
     ("s" "~/org/projects/work/shift-log/" "Shift log")
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

;; --------------------------------------------------
;; 19. Shift log
;; --------------------------------------------------
;;
;;   projects/work/shift-log/shift-log.org           project file, made with C-c n c p
;;   projects/work/shift-log/journal/YYYY.org        every shift, datetree by date
;;   projects/work/shift-log/reports/<date>-<shift>.org  one file per report
;;
;; A shift is a heading under its date, "Day shift" or "Night shift",
;; with SHIFT (day or night) and DUTY, who was on duty, in its drawer.
;; A night belongs to the date it starts on. Under it go plain list
;; items, as they come: who asked, what was found and done. Something
;; to follow up is a TODO heading under the shift; the journal is in
;; the agenda, the reports are not.
;;
;; A report is a copy of the last `my/shift-report-count' shifts, named
;; after the newest of them. Made again for the same newest shift, it
;; is rewritten: start the report when your shift starts, make it again
;; when the shift is filled in.

(defvar my/shift-dir (expand-file-name "projects/work/shift-log" my/org-dir)
  "Shift log project folder.")

(defvar my/shift-journal-dir (expand-file-name "journal" my/shift-dir)
  "One shift journal per year, named YYYY.org.")

(defvar my/shift-report-dir (expand-file-name "reports" my/shift-dir)
  "Generated reports.")

(defvar my/shift-report-count 4
  "Shifts in a report.")

(defvar my/shift-report-text-scale 2
  "Text size steps of an opened report, large enough to photograph.")

(defvar my/shift-kinds
  '(("day"   "Day shift"   "дневная смена")
    ("night" "Night shift" "ночная смена"))
  "SHIFT value, its journal heading, its name in reports.
Listed in the order shifts follow each other within a day.")

;; --- Journal --------------------------------------

(defun my/shift--journals ()
  "Shift journals, oldest year first."
  (when (file-directory-p my/shift-journal-dir)
    (directory-files my/shift-journal-dir t "\\`[0-9]\\{4\\}\\.org\\'")))

(defun my/shift--journal (year)
  "Shift journal for YEAR, created with its header when missing."
  (let ((file (expand-file-name (format "%d.org" year) my/shift-journal-dir)))
    (unless (file-exists-p file)
      (make-directory my/shift-journal-dir t)
      (write-region (format (concat "#+title: Shift log %d\n"
                                    "#+category: work\n"
                                    "#+property: DIR ../attachments\n")
                            year)
                    nil file))
    file))

(defun my/shift--duties ()
  "Everyone recorded as on duty, most recent first."
  (let ((names '()))
    (dolist (file (my/shift--journals))
      (with-temp-buffer
        (insert-file-contents file)
        (while (re-search-forward "^[ \t]*:DUTY:[ \t]+\\(.*?\\)[ \t]*$" nil t)
          (push (match-string 1) names))))
    (delete-dups (seq-remove #'string-empty-p names))))

(defun my/shift--find (shift)
  "Position of SHIFT under the date heading at point, nil when absent."
  (save-excursion
    (let ((end (save-excursion (org-end-of-subtree t) (point)))
          (stars (format "^\\*\\{%d\\} " (1+ (org-current-level))))
          found)
      (while (and (not found) (re-search-forward stars end t))
        (when (equal (org-entry-get nil "SHIFT") shift)
          (setq found (line-beginning-position))))
      found)))

(defun my/shift--create (shift duty)
  "Add SHIFT with DUTY under the date heading at point, in day order.
Leave point where the first item is typed."
  (let* ((level (1+ (org-current-level)))
         (later (seq-some #'my/shift--find
                          (cdr (member shift (mapcar #'car my/shift-kinds))))))
    (goto-char (or later (progn (org-end-of-subtree t t) (point))))
    (unless (bolp) (insert "\n"))
    (insert (make-string level ?*) " " (nth 1 (assoc shift my/shift-kinds)) "\n"
            ":PROPERTIES:\n"
            ":SHIFT:    " shift "\n"
            ":DUTY:     " duty "\n"
            ":END:\n"
            "- ")
    (unless (eobp)
      (save-excursion (insert "\n")))))

(defun my/shift-entry (date shift)
  "Open SHIFT of DATE in the shift log, ready for items.
A shift not logged yet is created, asking who was on duty. A night
shift belongs to the date it starts on."
  (interactive
   (list (org-read-date nil t nil "Shift date (a night: the date it starts): ")
         (completing-read "Shift: " (mapcar #'car my/shift-kinds) nil t)))
  (require 'org-datetree)
  (let ((d (decode-time date)))
    (pop-to-buffer-same-window
     (find-file-noselect (my/shift--journal (nth 5 d))))
    (widen)
    (org-datetree-find-date-create (list (nth 4 d) (nth 3 d) (nth 5 d)))
    (let ((pos (my/shift--find shift)))
      (if pos
          (progn
            (goto-char pos)
            (org-fold-reveal t)
            (org-fold-show-subtree)
            (org-end-of-subtree t))
        (my/shift--create shift (completing-read "On duty: " (my/shift--duties)))
        (org-fold-reveal t)
        (save-excursion
          (org-back-to-heading t)
          (org-fold-show-subtree))))))

(defun my/shift-journal (&optional pick)
  "Open this year's shift journal. With PICK (C-u), choose any year."
  (interactive "P")
  (find-file
   (if pick
       (read-file-name "Journal: " (file-name-as-directory my/shift-journal-dir)
                       nil t)
     (my/shift--journal (nth 5 (decode-time))))))

;; --- Report ---------------------------------------

(defun my/shift--body ()
  "Text of the shift at point after its drawer, trimmed."
  (save-excursion
    (let ((end (save-excursion (org-end-of-subtree t) (point))))
      (org-end-of-meta-data t)
      (if (< (point) end)
          (string-trim (buffer-substring-no-properties (point) end))
        ""))))

(defun my/shift--all ()
  "Every logged shift, oldest first, as (DATE SHIFT DUTY BODY)."
  (mapcan (lambda (file)
            (with-current-buffer (find-file-noselect file)
              (org-with-wide-buffer
               (org-map-entries
                (lambda ()
                  (let ((day (or (car (last (org-get-outline-path))) "")))
                    (list (substring day 0 (min 10 (length day)))
                          (org-entry-get nil "SHIFT")
                          (or (org-entry-get nil "DUTY") "")
                          (my/shift--body))))
                "SHIFT={.}" 'file))))
          (my/shift--journals)))

(defun my/shift-report (&optional count)
  "Write a report of the last COUNT shifts and open it.
COUNT defaults to `my/shift-report-count'; give another with C-u N.
The file is named after the newest shift. If it exists, it is
rewritten after a question, or opened as it is."
  (interactive "P")
  (let* ((count (if count (prefix-numeric-value count) my/shift-report-count))
         (shifts (last (my/shift--all) count)))
    (unless shifts
      (user-error "No shifts logged in %s" my/shift-journal-dir))
    (let* ((newest (car (last shifts)))
           (file (expand-file-name (format "%s-%s.org" (nth 0 newest) (nth 1 newest))
                                   my/shift-report-dir)))
      (when (or (not (file-exists-p file))
                (y-or-n-p (format "%s exists, make it again? Edits in it are lost. "
                                  (file-name-nondirectory file))))
        (make-directory my/shift-report-dir t)
        (with-current-buffer (find-file-noselect file)
          (erase-buffer)
          (insert (format "#+title: Отчёт за смены %s — %s\n"
                          (nth 0 (car shifts)) (nth 0 newest)))
          (dolist (s shifts)
            (insert "\n* " (nth 0 s) " "
                    (or (nth 2 (assoc (nth 1 s) my/shift-kinds)) (nth 1 s))
                    " " (nth 2 s) "\n")
            (unless (string-empty-p (nth 3 s))
              (insert (my/checklist--shift (nth 3 s) 2) "\n")))
          (save-buffer)))
      (find-file file)
      (org-fold-show-all)
      (goto-char (point-min))
      (text-scale-set my/shift-report-text-scale))))

(global-set-key (kbd "C-c r s") #'my/shift-entry)
(global-set-key (kbd "C-c r r") #'my/shift-report)
(global-set-key (kbd "C-c r l") #'my/shift-journal)

;;; init.el ends here
