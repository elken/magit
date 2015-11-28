;;; magit-remote.el --- transfer Git commits

;; Copyright (C) 2008-2015  The Magit Project Contributors
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

;; This library implements support for interacting with remote
;; repositories.  Commands for cloning, fetching, pulling, and
;; pushing are defined here.

;;; Code:

(require 'magit)

;;; Clone

;;;###autoload
(defun magit-clone (repository directory)
  "Clone the REPOSITORY to DIRECTORY.
Then show the status buffer for the new repository."
  (interactive
   (let  ((url (magit-read-string-ns "Clone repository")))
     (list url (read-directory-name
                "Clone to: " nil nil nil
                (and (string-match "\\([^./]+\\)\\(\\.git\\)?$" url)
                     (match-string 1 url))))))
  (setq directory (file-name-as-directory (expand-file-name directory)))
  (message "Cloning %s..." repository)
  (when (= (magit-call-git "clone" repository
                           ;; Stop cygwin git making a "c:" directory.
                           (magit-convert-git-filename directory))
           0)
    (message "Cloning %s...done" repository)
    (magit-status-internal directory)))

;;; Setup

;;;###autoload (autoload 'magit-remote-popup "magit-remote" nil t)
(magit-define-popup magit-remote-popup
  "Popup console for remote commands."
  'magit-commands nil nil
  :man-page "git-remote"
  :actions  '((?a "Add"     magit-remote-add)
              (?r "Rename"  magit-remote-rename)
              (?k "Remove"  magit-remote-remove)
              (?u "Set url" magit-remote-set-url)))

(defun magit-read-url (prompt &optional initial-input)
  (let ((url (magit-read-string-ns prompt initial-input)))
    (if (string-prefix-p "~" url)
        (expand-file-name url)
      url)))

;;;###autoload
(defun magit-remote-add (remote url)
  "Add a remote named REMOTE and fetch it."
  (interactive (list (magit-read-string-ns "Remote name")
                     (magit-read-url "Remote url")))
  (magit-run-git-async "remote" "add" "-f" remote url))

;;;###autoload
(defun magit-remote-rename (old new)
  "Rename the remote named OLD to NEW."
  (interactive
   (let  ((remote (magit-read-remote "Rename remote")))
     (list remote (magit-read-string-ns (format "Rename %s to" remote)))))
  (unless (string= old new)
    (magit-run-git "remote" "rename" old new)))

;;;###autoload
(defun magit-remote-set-url (remote url)
  "Change the url of the remote named REMOTE to URL."
  (interactive
   (let  ((remote (magit-read-remote "Set url of remote")))
     (list remote (magit-read-url
                   "Url" (magit-get "remote" remote "url")))))
  (magit-run-git "remote" "set-url" remote url))

;;;###autoload
(defun magit-remote-remove (remote)
  "Delete the remote named REMOTE."
  (interactive (list (magit-read-remote "Delete remote")))
  (magit-run-git "remote" "rm" remote))

;;; Fetch

;;;###autoload (autoload 'magit-fetch-popup "magit-remote" nil t)
(magit-define-popup magit-fetch-popup
  "Popup console for fetch commands."
  'magit-commands
  :man-page "git-fetch"
  :switches '((?p "Prune"      "--prune"))
  :actions  '((?f "Current"    magit-fetch-current)
              (?o "Other"      magit-fetch)
              (?a "All"        magit-fetch-all)
              (?m "Submodules" magit-submodule-fetch))
  :default-action 'magit-fetch-current)

(defun magit-git-fetch (remote args)
  (run-hooks 'magit-credential-hook)
  (magit-run-git-async-no-revert "fetch" remote args))

;;;###autoload
(defun magit-fetch-current (remote args)
  "Fetch from the upstream repository of the current branch.
If `HEAD' is detached or if the upstream is not configured,
then read the remote."
  (interactive (list (or (magit-get-remote)
                         (magit-read-remote "Fetch remote"))
                     (magit-fetch-arguments)))
  (magit-git-fetch remote args))

;;;###autoload
(defun magit-fetch (remote args)
  "Fetch from another repository."
  (interactive (list (magit-read-remote "Fetch remote")
                     (magit-fetch-arguments)))
  (magit-git-fetch remote args))

;;;###autoload
(defun magit-fetch-all (args)
  "Fetch from all configured remotes."
  (interactive (list (magit-fetch-arguments)))
  (run-hooks 'magit-credential-hook)
  (magit-run-git-async-no-revert "remote" "update" args))

;;; Pull

;;;###autoload (autoload 'magit-pull-popup "magit-remote" nil t)
(magit-define-popup magit-pull-popup
  "Popup console for pull commands."
  'magit-commands
  :man-page "git-pull"
  :switches '((?r "Rebase" "--rebase"))
  :actions  '((?F "Current" magit-pull-current)
              (?o "Other"   magit-pull))
  :default-action 'magit-pull-current)

(defun magit-git-pull (source args)
  (run-hooks 'magit-credential-hook)
  (-let [(remote . branch)
         (magit-split-branch-name source)]
    (magit-run-git-with-editor "pull" args remote branch)))

;;;###autoload
(defun magit-pull-current (source args)
  "Fetch and merge into current branch."
  (interactive (magit-pull-read-args t))
  (magit-git-pull source args))

;;;###autoload
(defun magit-pull (source args)
  "Fetch from another repository and merge a fetched branch."
  (interactive (magit-pull-read-args))
  (magit-git-pull source args))

(defun magit-pull-read-args (&optional use-upstream)
  (list (let ((source (magit-get-tracked-branch)))
          (or (and use-upstream source)
              (magit-read-remote-branch "Pull" nil source nil t)))
        (magit-pull-arguments)))

;;; Push

;;;###autoload (autoload 'magit-push-popup "magit-remote" nil t)
(magit-define-popup magit-push-popup
  "Popup console for push commands."
  'magit-commands
  :man-page "git-push"
  :switches '((?f "Force"         "--force-with-lease")
              (?h "Disable hooks" "--no-verify")
              (?d "Dry run"       "--dry-run")
              (?u "Set upstream"  "--set-upstream"))
  :actions  '((?P "Current"    magit-push-current)
              (?Q "Quickly"    magit-push-quickly)
              (?t "Tags"       magit-push-tags)
              (?o "Other"      magit-push)
              (?m "Matching"   magit-push-matching)
              (?T "Tag"        magit-push-tag)
              (?e "Elsewhere"  magit-push-elsewhere))
  :default-action 'magit-push-current
  :max-action-columns 3)

(defun magit-git-push (branch target args)
  (run-hooks 'magit-credential-hook)
  (-let [(remote . target)
         (magit-split-branch-name target)]
    (magit-run-git-async-no-revert "push" "-v" args remote
                                   (format "%s:refs/heads/%s"
                                           branch target))))

;;;###autoload
(defun magit-push-quickly (args)
  "Push the current branch to `branch.<name>.pushRemote'.
If that variable is unset, then push to `remote.pushDefault'.
If that variable is unset too, then raise an error."
  (interactive (list (magit-push-arguments)))
  (--if-let (magit-get-current-branch)
      (-if-let (remote (magit-get-push-remote it))
          (if (member remote (magit-list-remotes))
              (magit-git-push it (concat remote "/" it) args)
            (user-error "Remote `%s' doesn't exist" remote))
        (user-error "No push-remote is configured for %s" it))
    (user-error "No branch is checked out")))

;;;###autoload
(defun magit-push-current (branch target args)
  "Push the current branch to its upstream branch.
If the upstream isn't set, then read the remote branch."
  (interactive (magit-push-read-args t t))
  (magit-git-push branch target args))

;;;###autoload
(defun magit-push-elsewhere (branch target args)
  "Push the current branch to a branch read in the minibuffer."
  (interactive
   (-if-let (branch (magit-get-current-branch))
       (list branch
             (magit-read-remote-branch (format "Push %s to" branch)
                                       nil nil branch 'confirm)
             (magit-push-arguments))
     (list nil nil nil)))
  (if (and branch target)
      (magit-git-push branch target args)
    (call-interactively 'magit-push)))

;;;###autoload
(defun magit-push (source target args)
  "Push an arbitrary branch or commit somewhere.
Both the source and the target are read in the minibuffer."
  (interactive
   (let ((source (magit-read-local-branch-or-commit "Push")))
     (list source
           (magit-read-remote-branch (format "Push %s to" source) nil
                                     (magit-get-tracked-branch source)
                                     source 'confirm)
           (magit-push-arguments))))
  (magit-git-push source target args))

(defun magit-push-read-args (&optional use-upstream use-current default-current)
  (let* ((current (magit-get-current-branch))
         (local (or (and use-current current)
                    (magit-completing-read
                     "Push" (--if-let (magit-commit-at-point)
                                (cons it (magit-list-local-branch-names))
                              (magit-list-local-branch-names))
                     nil nil nil 'magit-revision-history
                     (or (and default-current current)
                         (magit-local-branch-at-point)
                         (magit-commit-at-point)))
                    (user-error "Nothing selected")))
         (target (and (magit-branch-p local)
                      (magit-get-tracked-branch local))))
    (unless (and use-upstream target)
      (setq target (magit-read-remote-branch (format "Push %s to" local)
                                             nil target local 'confirm)))
    (list local target (magit-push-arguments))))

;;;###autoload
(defun magit-push-matching (remote &optional args)
  "Push all matching branches to another repository.
If multiple remotes exit, then read one from the user.
If just one exists, use that without requiring confirmation."
  (interactive (list (magit-read-remote "Push matching branches to" nil t)
                     (magit-push-arguments)))
  (run-hooks 'magit-credential-hook)
  (magit-run-git-async-no-revert "push" "-v" args remote ":"))

;;;###autoload
(defun magit-push-tags (remote &optional args)
  "Push all tags to another repository.
If only one remote exists, then push to that.  Otherwise prompt
for a remote, offering the remote configured for the current
branch as default."
  (interactive (list (magit-read-remote "Push tags to remote" nil t)
                     (magit-push-arguments)))
  (run-hooks 'magit-credential-hook)
  (magit-run-git-async-no-revert "push" remote "--tags" args))

;;;###autoload
(defun magit-push-tag (tag remote &optional args)
  "Push a tag to another repository."
  (interactive
   (let  ((tag (magit-read-tag "Push tag")))
     (list tag (magit-read-remote (format "Push %s to remote" tag) nil t)
           (magit-push-arguments))))
  (run-hooks 'magit-credential-hook)
  (magit-run-git-async-no-revert "push" remote tag))

;;; Email

;;;###autoload (autoload 'magit-patch-popup "magit-remote" nil t)
(magit-define-popup magit-patch-popup
  "Popup console for patch commands."
  'magit-commands
  :man-page "git-format-patch"
  :options  '((?f "From"             "--from=")
              (?t "To"               "--to=")
              (?c "CC"               "--cc=")
              (?r "In reply to"      "--in-reply-to=")
              (?v "Reroll count"     "--reroll-count=")
              (?s "Thread style"     "--thread=")
              (?U "Context lines"    "-U")
              (?M "Detect renames"   "-M")
              (?C "Detect copies"    "-C")
              (?A "Diff algorithm"   "--diff-algorithm="
                  magit-diff-select-algorithm)
              (?o "Output directory" "--output-directory="))
  :actions  '((?p "Format patches"   magit-format-patch)
              (?r "Request pull"     magit-request-pull))
  :default-action 'magit-format-patch)

;;;###autoload
(defun magit-format-patch (range args)
  "Create patches for the commits in RANGE.
When a single commit is given for RANGE, create a patch for the
changes introduced by that commit (unlike 'git format-patch'
which creates patches for all commits that are reachable from
HEAD but not from the specified commit)."
  (interactive
   (list (-if-let (revs (magit-region-values 'commit))
             (concat (car (last revs)) "^.." (car revs))
           (let ((range (magit-read-range-or-commit "Format range or commit")))
             (if (string-match-p "\\.\\." range)
                 range
               (format "%s~..%s" range range))))
         (magit-patch-arguments)))
  (magit-run-git-no-revert "format-patch" range args))

;;;###autoload
(defun magit-request-pull (url start end)
  "Request upstream to pull from you public repository.

URL is the url of your publically accessible repository.
START is a commit that already is in the upstream repository.
END is the last commit, usually a branch name, which upstream
is asked to pull.  START has to be reachable from that commit."
  (interactive
   (list (magit-get "remote" (magit-read-remote "Remote") "url")
         (magit-read-branch-or-commit "Start" (magit-get-tracked-branch))
         (magit-read-branch-or-commit "End")))
  (let ((dir default-directory))
    ;; mu4e changes default-directory
    (compose-mail)
    (setq default-directory dir))
  (message-goto-body)
  (let ((inhibit-magit-revert t))
    (magit-git-insert "request-pull" start url))
  (set-buffer-modified-p nil))

;;; magit-remote.el ends soon
(provide 'magit-remote)
;; Local Variables:
;; indent-tabs-mode: nil
;; End:
;;; magit-remote.el ends here
