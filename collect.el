;;; collect.el --- org agenda snapshot for the Omarchy bar -*- lexical-binding: t -*-

;; Loaded into the running Emacs daemon by collect.sh. Uses org-agenda's own
;; entry collection, so repeaters, deadline warnings, overdue items and TODO
;; keywords match what `org-agenda-list' shows.

(require 'org)
(require 'org-agenda)
(require 'json)

(defun omarchy-org-agenda--item (entry)
  "Turn agenda ENTRY (a propertized string) into an alist."
  (let* ((marker (or (get-text-property 0 'org-hd-marker entry)
                     (get-text-property 0 'org-marker entry)))
         (buffer (and marker (marker-buffer marker)))
         (todo (get-text-property 0 'todo-state entry))
         (time (get-text-property 0 'time-of-day entry))
         title file line tags)
    (when buffer
      (with-current-buffer buffer
        (org-with-wide-buffer
         (goto-char marker)
         (setq title (org-link-display-format (org-get-heading t t t t))
               file (buffer-file-name (buffer-base-buffer))
               line (line-number-at-pos)
               tags (org-get-tags nil t)))))
    `((title . ,(or title (substring-no-properties
                           (or (get-text-property 0 'txt entry) entry))))
      (todo . ,(and todo (substring-no-properties todo)))
      (done . ,(if (and todo (member todo org-done-keywords-for-agenda)) t :json-false))
      (type . ,(or (get-text-property 0 'type entry) ""))
      (extra . ,(string-trim (replace-regexp-in-string
                              " +" " " (or (get-text-property 0 'extra entry) ""))))
      (time . ,(and time (format "%02d:%02d" (/ time 100) (% time 100))))
      (category . ,(or (get-text-property 0 'org-category entry) ""))
      (tags . ,(vconcat tags))
      (file . ,file)
      (line . ,line))))

(defun omarchy-org-agenda--day (files date)
  "Agenda entries for DATE (calendar list) across FILES."
  (let ((org-agenda-current-date date)
        entries)
    (dolist (file files)
      (setq entries
            (append entries
                    (org-agenda-get-day-entries
                     file date :deadline :scheduled :timestamp :sexp))))
    (sort (mapcar #'omarchy-org-agenda--item entries)
          (lambda (a b)
            (string< (or (alist-get 'time a) "99") (or (alist-get 'time b) "99"))))))

(defun omarchy-org-agenda--todos (files keyword)
  "Open headings with todo KEYWORD across FILES."
  (let (items)
    (dolist (file files)
      (with-current-buffer (org-get-agenda-file-buffer file)
        (org-with-wide-buffer
         (org-map-entries
          (lambda ()
            (push `((title . ,(org-link-display-format (org-get-heading t t t t)))
                    (todo . ,keyword)
                    (done . :json-false)
                    (type . "todo")
                    (category . ,(or (org-get-category) ""))
                    (tags . ,(vconcat (org-get-tags nil t)))
                    (file . ,(buffer-file-name (buffer-base-buffer)))
                    (line . ,(line-number-at-pos)))
                  items))
          (format "TODO=\"%s\"" keyword) 'file))))
    (nreverse items)))

(defun omarchy-org-agenda-json (days next-keyword)
  "JSON snapshot: DAYS of agenda starting today plus NEXT-KEYWORD todos."
  (let* ((files (org-agenda-files nil 'ifmode))
         (today (calendar-current-date))
         (start (calendar-absolute-from-gregorian today))
         (org-agenda-buffer-name "*omarchy-org-agenda*")
         day-list)
    (org-agenda-prepare-buffers files)
    (org-compile-prefix-format 'agenda)
    (dotimes (i days)
      (let ((date (calendar-gregorian-from-absolute (+ start i))))
        (push `((date . ,(format "%04d-%02d-%02d"
                                 (nth 2 date) (nth 0 date) (nth 1 date)))
                (offset . ,i)
                (items . ,(vconcat (omarchy-org-agenda--day files date))))
              day-list)))
    (json-encode
     `((generatedAt . ,(format-time-string "%FT%T%z"))
       (days . ,(vconcat (nreverse day-list)))
       (next . ,(vconcat (if (string-empty-p next-keyword)
                             nil
                           (omarchy-org-agenda--todos files next-keyword))))))))

;;; collect.el ends here
