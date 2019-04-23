;;; magit-clone.el --- clone a repository  -*- lexical-binding: t -*-

;; Copyright (C) 2008-2019  The Magit Project Contributors
;;
;; You should have received a copy of the AUTHORS.md file which
;; lists all contributors.  If not, see http://magit.vc/authors.

;; Author: Jonas Bernoulli <jonas@bernoul.li>
;; Maintainer: Jonas Bernoulli <jonas@bernoul.li>

;; Magit is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; Magit is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
;; License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with Magit.  If not, see http://www.gnu.org/licenses.

;;; Commentary:

;; This library implements clone commands.

;;; Code:

(require 'magit)

;;; Options

(defcustom magit-clone-set-remote-head nil
  "Whether cloning creates the symbolic-ref `<remote>/HEAD'."
  :package-version '(magit . "2.4.2")
  :group 'magit-commands
  :type 'boolean)

(defcustom magit-clone-set-remote.pushDefault 'ask
  "Whether to set the value of `remote.pushDefault' after cloning.

If t, then set without asking.  If nil, then don't set.  If
`ask', then ask."
  :package-version '(magit . "2.4.0")
  :group 'magit-commands
  :type '(choice (const :tag "set" t)
                 (const :tag "ask" ask)
                 (const :tag "don't set" nil)))

(defcustom magit-clone-default-directory nil
  "Default directory to use when `magit-clone' reads destination.
If nil (the default), then use the value of `default-directory'.
If a directory, then use that.  If a function, then call that
with the remote url as only argument and use the returned value."
  :package-version '(magit . "2.90.0")
  :group 'magit-commands
  :type '(choice (const     :tag "value of default-directory")
                 (directory :tag "constant directory")
                 (function  :tag "function's value")))

(defcustom magit-clone-always-transient nil
  "Whether `magit-clone' always acts as a transient prefix command.
If nil, then a prefix argument has to be used to show the transient
popup instead of invoking the default suffix `magit-clone-regular'
directly."
  :package-version '(magit . "2.91.0")
  :group 'magit-commands
  :type 'boolean)

;;; Commands

;;;###autoload (autoload 'magit-clone "magit-clone" nil t)
(define-transient-command magit-clone (&optional transient)
  "Clone a repository."
  :man-page "git-clone"
  ["Clone"
   ("C" "regular"            magit-clone-regular)
   ("s" "shallow"            magit-clone-shallow)
   ("d" "shallow since date" magit-clone-shallow-since :level 7)
   ("e" "shallow excluding"  magit-clone-shallow-exclude :level 7)
   ("b" "bare"               magit-clone-bare)
   ("m" "mirror"             magit-clone-mirror)]
  (interactive (list (or magit-clone-always-transient current-prefix-arg)))
  (if transient
      (transient-setup #'magit-clone)
    (call-interactively #'magit-clone-regular)))

;;;###autoload
(defun magit-clone-regular (repository directory args)
  "Create a clone of REPOSITORY in DIRECTORY.
Then show the status buffer for the new repository."
  (interactive (magit-clone-read-args))
  (magit-clone-internal repository directory args))

;;;###autoload
(defun magit-clone-shallow (repository directory args depth)
  "Create a shallow clone of REPOSITORY in DIRECTORY.
Then show the status buffer for the new repository.
With a prefix argument read the DEPTH of the clone;
otherwise use 1."
  (interactive (append (magit-clone-read-args)
                       (list (if current-prefix-arg
                                 (read-number "Depth: " 1)
                               1))))
  (magit-clone-internal repository directory
                        (cons (format "--depth=%s" depth) args)))

;;;###autoload
(defun magit-clone-shallow-since (repository directory args date)
  "Create a shallow clone of REPOSITORY in DIRECTORY.
Then show the status buffer for the new repository.
Exclude commits before DATE, which is read from the
user."
  (interactive (append (magit-clone-read-args)
                       (list (transient-read-date "Exclude commits before: "
                                                  nil nil))))
  (magit-clone-internal repository directory
                        (cons (format "--shallow-since=%s" date) args)))

;;;###autoload
(defun magit-clone-shallow-exclude (repository directory args exclude)
  "Create a shallow clone of REPOSITORY in DIRECTORY.
Then show the status buffer for the new repository.
Exclude commits reachable from EXCLUDE, which is a
branch or tag read from the user."
  (interactive (append (magit-clone-read-args)
                       (list (read-string "Exclude commits reachable from: "))))
  (magit-clone-internal repository directory
                        (cons (format "--shallow-exclude=%s" exclude) args)))

;;;###autoload
(defun magit-clone-bare (repository directory args)
  "Create a bare clone of REPOSITORY in DIRECTORY.
Then show the status buffer for the new repository."
  (interactive (magit-clone-read-args))
  (magit-clone-internal repository directory (cons "--bare" args)))

;;;###autoload
(defun magit-clone-mirror (repository directory args)
  "Create a mirror of REPOSITORY in DIRECTORY.
Then show the status buffer for the new repository."
  (interactive (magit-clone-read-args))
  (magit-clone-internal repository directory (cons "--mirror" args)))

(defun magit-clone-internal (repository directory args)
  (run-hooks 'magit-credential-hook)
  (setq directory (file-name-as-directory (expand-file-name directory)))
  (magit-run-git-async "clone" args "--" repository
                       (magit-convert-filename-for-git directory))
  ;; Don't refresh the buffer we're calling from.
  (process-put magit-this-process 'inhibit-refresh t)
  (set-process-sentinel
   magit-this-process
   (lambda (process event)
     (when (memq (process-status process) '(exit signal))
       (let ((magit-process-raise-error t))
         (magit-process-sentinel process event)))
     (when (and (eq (process-status process) 'exit)
                (= (process-exit-status process) 0))
       (unless (memq (car args) '("--bare" "--mirror"))
         (let ((default-directory directory))
           (when (or (eq  magit-clone-set-remote.pushDefault t)
                     (and magit-clone-set-remote.pushDefault
                          (y-or-n-p "Set `remote.pushDefault' to \"origin\"? ")))
             (setf (magit-get "remote.pushDefault") "origin"))
           (unless magit-clone-set-remote-head
             (magit-remote-unset-head "origin"))))
       (with-current-buffer (process-get process 'command-buf)
         (magit-status-setup-buffer directory))))))

(defun magit-clone-read-args ()
  (let  ((url (magit-read-string-ns "Clone repository")))
    (list url
          (read-directory-name
           "Clone to: "
           (if (functionp magit-clone-default-directory)
               (funcall magit-clone-default-directory url)
             magit-clone-default-directory)
           nil nil
           (and (string-match "\\([^/:]+?\\)\\(/?\\.git\\)?$" url)
                (match-string 1 url)))
          (transient-args 'magit-clone))))

;;; _
(provide 'magit-clone)
;;; magit-clone.el ends here
