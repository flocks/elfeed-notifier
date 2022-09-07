;;; elfeed-notifier.el --- get elfeed notifications for new entries

;; Author: Florent Teissier <teissierflorent@gmail.com>
;; URL: https://github.com/flocks/elfeed-notifier

;;; Commentary:

;; Elfeed-notifier let you get notifications in your modeline when new entries
;; populate your elfeed db

;;; Code:

(require 'elfeed)

(defgroup elfeed-notifier ()
  "Notifications for elfeed"
  :group 'convenience)

(defcustom elfeed-notifier-query elfeed-search-filter
  "Query string filtering entries that is run to compute the total
number of notifications.

It defaults to `elfeed-search-filter' which what you most likely want. But you
could narrow the result if you only want to get notified when your favorite feeds
get new entries."
  :group 'elfeed-notifier
  :type 'string)

;;; TODO implement a setter to redraw when change
(defcustom elfeed-notifier-modeline-formatter
  #'elfeed-notifier-default-mode-line-formatter
  "The function used to get the string to be displayed in the mode-line.
It should be a function that accepts as the single argument the
current count of elfeed entries and should return the string to
be displayed in the mode-line."
  :type 'function
  :group 'elfeed-notifier)

(defcustom elfeed-notifier-refresh-when-elfeed-used-p nil
  "Whether we want to update feeds while we are currently using
elfeed or not"
  :type 'boolean
  :group 'elfeed-notifier)

;;; TODO implement a setter so we cancel previous timer when we update this value
;;; and re-create a timer
(defcustom elfeed-notifier-delay 300
  "Delay between each synchronization with your feeds"
  :group 'elfeed-notifier
  :type 'number)

(defface elfeed-notifier-modeline-face
  '((t :inherit font-lock-warning-face))
  "Face for showing the number in the modeline."
  :group 'elfeed-notifier)


(defvar elfeed-notifier-alert-mode-line nil 
  "The mode-line indicator to display the count of elfeed entries.")


(defvar elfeed-notifier--timer "store the TIMER object" nil)

(defun elfeed-notifier-default-mode-line-formatter (nb)
  "Take the number NB of entries and format the string for the
modeline"
  (when (> nb 0)
	(propertize (format "[N:%s] " nb) 'face 'elfeed-notifier-modeline-face)))

(defun elfeed-notifier--update-hook (&rest _)
  "Hook that is run every time the elfeed db changes.

It takes `elfeed-notifier-query' filter and query the db with it to get
the number."
  (let* ((filter (elfeed-search-parse-filter elfeed-notifier-query))
		 (func (byte-compile (elfeed-search-compile-filter filter)))
		 (count 0))
	(with-elfeed-db-visit (entry feed)
	  (when (funcall func entry feed count)
		(setf count (1+ count))))
	(setq elfeed-notifier-alert-mode-line
		  (funcall elfeed-notifier-modeline-formatter count))))


(defun elfeed-notifier-update ()
  "Function run every `elfeed-notifier-delay' second to update
elfeed db.

When `elfeed-notifier-refresh-when-elfeed-used-p' is nil, do not perform
update when *elfeed-search* buffer is focused"

  (when (or elfeed-notifier-refresh-when-elfeed-used-p
			(not (string= "*elfeed-search*" (buffer-name (current-buffer)))))
	(elfeed-update)))

(defun elfeed-notifier-enable ()
  "Enable the mode by adding all hooks needed, set up the timer
function that will run every `elfeed-notifier-delay' and append
the alert mode-line to global-mode-string"
  (add-hook 'elfeed-search-update-hook #'elfeed-notifier--update-hook)
  (add-hook 'elfeed-untag-hooks #'elfeed-notifier--update-hook)
  (setq elfeed-notifier--timer
		(run-at-time t elfeed-notifier-delay #'elfeed-notifier-update))

  (add-to-list 'global-mode-string '(:eval elfeed-notifier-alert-mode-line) t))

(defun elfeed-notifier-disable ()
  "Disable the mode by removing all hooks added, clean the
timer, and remove the alert from global-mode-string"
  (remove-hook 'elfeed-search-update-hook #'elfeed-notifier--update-hook)
  (remove-hook 'elfeed-untag-hooks #'elfeed-notifier--update-hook)
  (setq global-mode-string (delete '(:eval elfeed-notifier-alert-mode-line) global-mode-string))
  (when (timerp elfeed-notifier--timer)
	(cancel-timer elfeed-notifier--timer))
  (setq elfeed-notifier--timer nil))


(define-minor-mode elfeed-notifier-mode
  "Global minor mode that notify when new elfeed entries populate
the db"
  :global t
  (if elfeed-notifier-mode
	  (elfeed-notifier-enable)
	(elfeed-notifier-disable)))

(provide 'elfeed-notifier)

;;; elfeed-notifier.el ends here
