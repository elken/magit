-include ../config.mk
include ../default.mk

## ###################################################################

.PHONY: magit-version.el check-declare install

all: lisp

## Build order #######################################################

magit-section.elc:
magit-base.elc:            magit-section.elc
magit-git.elc:             magit-base.elc
# FIXME                    magit-process magit-mode (magit-margin)
ifeq "$(BUILD_MAGIT_LIBGIT)" "true"
magit-libgit.elc:          magit-git.elc
endif

git-commit.elc:            magit-base.elc magit-git.elc
magit-autorevert.elc:      magit-base.elc magit-git.elc
magit-mode.elc:            magit-base.elc magit-git.elc \
                           git-commit.elc magit-autorevert.elc
# FIXME                    magit-process magit-diff magit-status magit-bookmark
magit-margin.elc:          magit-base.elc magit-git.elc magit-mode.elc
magit-process.elc:         magit-base.elc magit-git.elc magit-mode.elc
magit-transient.elc:       magit-base.elc magit-git.elc magit-mode.elc magit-process.elc
magit-core.elc:            magit-base.elc magit-git.elc magit-mode.elc magit-process.elc \
                           git-commit.elc magit-autorevert.elc \
                           magit-margin.elc magit-transient.elc

magit-diff.elc:            magit-core.elc
# FIXME                    magit-stash magit-files magit-commit git-rebase
# FIXME                    magit-merge magit-log
magit-log.elc:             magit-core.elc magit-diff.elc
magit-reflog.elc:          magit-core.elc magit-log.elc
magit-wip.elc:             magit-core.elc magit-log.elc
magit-apply.elc:           magit-core.elc magit-diff.elc magit-wip.elc
# FIXME                    magit-sequence magit-patch magit-merge magit-submodule
magit.elc:                 magit-core.elc magit-diff.elc magit-log.elc \
                           magit-reflog.elc magit-wip.elc magit-apply.elc

magit-files.elc:           magit.elc

magit-notes.elc:           magit.elc
magit-reset.elc:           magit.elc
magit-branch.elc:          magit.elc magit-reset.elc
magit-worktree.elc:        magit.elc magit-branch.elc
magit-refs.elc:            magit.elc magit-branch.elc
magit-tag.elc:             magit.elc magit-refs.elc

magit-remote.elc:          magit.elc
# FIXME                    magit-fetch
magit-clone.elc:           magit.elc magit-remote.elc magit-status.elc
magit-fetch.elc:           magit.elc magit-remote.elc
magit-pull.elc:            magit.elc magit-remote.elc
magit-push.elc:            magit.elc magit-remote.elc magit-notes.elc
magit-sequence.elc:        magit.elc magit-remote.elc magit-pull.elc magit-branch.elc
# FIXME                    git-rebase magit-commit
magit-commit.elc:          magit.elc magit-sequence.elc
magit-merge.elc:           magit.elc magit-branch.elc magit-push.elc
magit-stash.elc:           magit.elc magit-sequence.elc magit-merge.elc

magit-bisect.elc:          magit.elc                     # +sections
magit-blame.elc:           magit.elc magit-files.elc
magit-bundle.elc:          magit.elc
magit-ediff.elc:           magit.elc magit-files.elc
magit-gitignore.elc:       magit.elc magit-files.elc
magit-patch.elc:           magit.elc magit-notes.elc
magit-sparse-checkout.elc: magit.elc                     # +sections
magit-repos.elc:           magit.elc
magit-submodule.elc:       magit.elc magit-repos.elc     # +sections
magit-subtree.elc:         magit.elc

magit-extras.elc:          magit.elc magit-bisect.elc magit-blame.elc \
                           magit-commit.elc magit-merge.elc magit-sequence.elc \
                           magit-status.elc
git-rebase.elc:            magit.elc magit-stash.elc

magit-bookmark.elc:        magit.elc

magit-obsolete.elc:        magit.elc # (magit-repos)

magit-status.elc:          magit.elc magit-bisect.elc magit-merge.elc \
                           magit-repos.elc magit-sequence.elc \
                           magit-stash.elc magit-worktree.elc

## Build #############################################################

lisp:       $(ELCS) loaddefs $(LISP_EXTRA_TARGETS)
loaddefs:   $(PKG)-autoloads.el
versionlib: $(PKG)-version.el

%.elc: %.el
	@printf "Compiling $<\n"
	@$(BATCH) --eval "(progn\
	(when (file-exists-p \"$@\")\
	  (delete-file \"$@\"))\
	(setq with-editor-emacsclient-executable nil)\
	$$suppress_warnings)" \
	-f batch-byte-compile $<

$(PKG)-autoloads.el: $(ELS)
	@printf " Creating $@\n"
	@$(EMACS) -Q --batch -l autoload -l cl-lib --eval "\
(let ((file (expand-file-name \"$@\"))\
      (autoload-timestamps nil) \
      (backup-inhibited t)\
      (version-control 'never)\
      (coding-system-for-write 'utf-8-emacs-unix))\
  (write-region (autoload-rubric file \"package\" nil) nil file nil 'silent)\
  (cl-letf (((symbol-function 'progress-reporter-do-update) (lambda (&rest _)))\
            ((symbol-function 'progress-reporter-done) (lambda (_))))\
    (let ((generated-autoload-file file))\
      (update-directory-autoloads default-directory))))"
$(PKG)-version.el:
	@printf " Creating $@\n"
	@printf "%s" "$$VERSIONLIB_TMPL" > $@

check-declare:
	@printf "Checking function declarations\n"
	@$(BATCH) -L $(TOP)../borg -L $(TOP)../forge/lisp \
	--eval "(check-declare-directory default-directory)"

## Install ###########################################################

install: lisp versionlib
	@$(MKDIR) $(DESTDIR)$(lispdir)
	$(CP) $(ELS) magit-autoloads.el magit-version.el $(ELCS) $(DESTDIR)$(lispdir)

## Clean #############################################################

clean:
	@printf " Cleaning lisp/*...\n"
	@$(RM) *.elc $(ELGS)

## Templates #########################################################

define VERSIONLIB_TMPL
;;; $(PKG)-version.el --- the Magit version you are using

(setq $(PKG)-version "$(VERSION)")

(provide '$(PKG)-version)

;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; coding: utf-8
;; End:
;;; $(PKG)-version.el ends here

endef
export VERSIONLIB_TMPL
#'

define suppress_warnings
(fset 'original-message (symbol-function 'message))
(fset 'message ;'
      (lambda (f &rest a)
        (unless (or (equal f "Wrote %s")
                    (equal f "pcase-memoize: equal first branch, yet different")
                    (and (equal f "Warning: Unknown defun property `%S' in %S")
                         (memq (car a) '(pure side-effect-free interactive-only))))
          (apply 'original-message f a))))
endef
export suppress_warnings
