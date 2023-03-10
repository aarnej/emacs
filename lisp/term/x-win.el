;;; x-win.el --- parse relevant switches and set up for X  -*- lexical-binding:t -*-

;; Copyright (C) 1993-1994, 2001-2023 Free Software Foundation, Inc.

;; Author: FSF
;; Keywords: terminals, i18n

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; X-win.el: this file defines functions to initialize the X window
;; system and process X-specific command line parameters before
;; creating the first X frame.

;; Beginning in Emacs 23, the act of loading this file should not have
;; the side effect of initializing the window system or processing
;; command line arguments (this file is now loaded in loadup.el).  See
;; `handle-args-function' and `window-system-initialization' for more details.

;; startup.el will then examine startup files, and eventually call the hooks
;; which create the first window(s).

;;; Code:

;; These are the standard X switches from the Xt Initialize.c file of
;; Release 4.

;; Command line		Resource Manager string

;; +rv			*reverseVideo
;; +synchronous		*synchronous
;; -background		*background
;; -bd			*borderColor
;; -bg			*background
;; -bordercolor		*borderColor
;; -borderwidth		.borderWidth
;; -bw			.borderWidth
;; -display		.display
;; -fg			*foreground
;; -fn			*font
;; -font		*font
;; -foreground		*foreground
;; -geometry		.geometry
;; -iconic		.iconic
;; -name		.name
;; -reverse		*reverseVideo
;; -rv			*reverseVideo
;; -selectionTimeout    .selectionTimeout
;; -synchronous		*synchronous
;; -xrm

;; An alist of X options and the function which handles them.  See
;; ../startup.el.

(eval-when-compile (require 'cl-lib))

(if (not (fboundp 'x-create-frame))
    (error "%s: Loading x-win.el but not compiled for X" invocation-name))

(require 'term/common-win)
(require 'frame)
(require 'mouse)
(require 'scroll-bar)
(require 'select)
(require 'menu-bar)
(require 'fontset)
(require 'x-dnd)

(defvar x-invocation-args)
(defvar x-keysym-table)
(defvar x-selection-timeout)
(defvar x-session-id)
(defvar x-session-previous-id)
(defvar x-dnd-movement-function)
(defvar x-dnd-unsupported-drop-function)

(defun x-handle-no-bitmap-icon (_switch)
  (setq default-frame-alist (cons '(icon-type) default-frame-alist)))

;; Handle the --parent-id option.
(defun x-handle-parent-id (switch)
  (or (consp x-invocation-args)
      (error "%s: missing argument to `%s' option" invocation-name switch))
  (setq initial-frame-alist (cons
                             (cons 'parent-id
                                   (string-to-number (car x-invocation-args)))
                             initial-frame-alist)
        x-invocation-args (cdr x-invocation-args)))

;; Handle the --smid switch.  This is used by the session manager
;; to give us back our session id we had on the previous run.
(defun x-handle-smid (switch)
  (or (consp x-invocation-args)
      (error "%s: missing argument to `%s' option" invocation-name switch))
  (setq x-session-previous-id (car x-invocation-args)
	x-invocation-args (cdr x-invocation-args)))

(defun emacs-session-filename (session-id)
  "Construct a filename to save the session in based on SESSION-ID.
Return a filename in `user-emacs-directory', unless the session file
already exists in the home directory."
  (let ((basename (concat "session." session-id)))
    (locate-user-emacs-file basename
                            (concat ".emacs-" basename))))

(defun emacs-session-save ()
  "This function is called when the window system is shutting down.
If this function returns non-nil, the window system shutdown is canceled.

When a session manager tells Emacs that the window system is shutting
down, this function is called.  It calls the functions in the hook
`emacs-save-session-functions'.  Functions are called with the current
buffer set to a temporary buffer.  Functions should use `insert' to insert
Lisp code to save the session state.  The buffer is saved in a file in the
home directory of the user running Emacs.  The file is evaluated when
Emacs is restarted by the session manager.

If any of the functions returns non-nil, no more functions are called
and this function returns non-nil.  This will inform the session manager
that it should abort the window system shutdown."
  (let ((filename (emacs-session-filename x-session-id))
	(buf (get-buffer-create (concat " *SES " x-session-id))))
    (when (file-exists-p filename)
      (delete-file filename))
    (with-current-buffer buf
      (let ((cancel-shutdown (condition-case nil
				 ;; A return of t means cancel the shutdown.
				 (run-hook-with-args-until-success
				  'emacs-save-session-functions)
			       (error t))))
	(unless cancel-shutdown
	  (write-file filename))
	(kill-buffer buf)
	cancel-shutdown))))

(defun emacs-session-restore (previous-session-id)
  "Restore the Emacs session if started by a session manager.
The file saved by `emacs-session-save' is evaluated and deleted if it
exists."
  (let ((filename (emacs-session-filename previous-session-id)))
    (when (file-exists-p filename)
      (load-file filename)
      (delete-file filename)
      (message "Restored session data"))))




;;
;; Standard X cursor shapes, courtesy of Mr. Fox, who wanted ALL of them.
;;

(defconst x-pointer-X-cursor 0)
(defconst x-pointer-arrow 2)
(defconst x-pointer-based-arrow-down 4)
(defconst x-pointer-based-arrow-up 6)
(defconst x-pointer-boat 8)
(defconst x-pointer-bogosity 10)
(defconst x-pointer-bottom-left-corner 12)
(defconst x-pointer-bottom-right-corner 14)
(defconst x-pointer-bottom-side 16)
(defconst x-pointer-bottom-tee 18)
(defconst x-pointer-box-spiral 20)
(defconst x-pointer-center-ptr 22)
(defconst x-pointer-circle 24)
(defconst x-pointer-clock 26)
(defconst x-pointer-coffee-mug 28)
(defconst x-pointer-cross 30)
(defconst x-pointer-cross-reverse 32)
(defconst x-pointer-crosshair 34)
(defconst x-pointer-diamond-cross 36)
(defconst x-pointer-dot 38)
(defconst x-pointer-dotbox 40)
(defconst x-pointer-double-arrow 42)
(defconst x-pointer-draft-large 44)
(defconst x-pointer-draft-small 46)
(defconst x-pointer-draped-box 48)
(defconst x-pointer-exchange 50)
(defconst x-pointer-fleur 52)
(defconst x-pointer-gobbler 54)
(defconst x-pointer-gumby 56)
(defconst x-pointer-hand1 58)
(defconst x-pointer-hand2 60)
(defconst x-pointer-heart 62)
(defconst x-pointer-icon 64)
(defconst x-pointer-iron-cross 66)
(defconst x-pointer-left-ptr 68)
(defconst x-pointer-left-side 70)
(defconst x-pointer-left-tee 72)
(defconst x-pointer-leftbutton 74)
(defconst x-pointer-ll-angle 76)
(defconst x-pointer-lr-angle 78)
(defconst x-pointer-man 80)
(defconst x-pointer-middlebutton 82)
(defconst x-pointer-mouse 84)
(defconst x-pointer-pencil 86)
(defconst x-pointer-pirate 88)
(defconst x-pointer-plus 90)
(defconst x-pointer-question-arrow 92)
(defconst x-pointer-right-ptr 94)
(defconst x-pointer-right-side 96)
(defconst x-pointer-right-tee 98)
(defconst x-pointer-rightbutton 100)
(defconst x-pointer-rtl-logo 102)
(defconst x-pointer-sailboat 104)
(defconst x-pointer-sb-down-arrow 106)
(defconst x-pointer-sb-h-double-arrow 108)
(defconst x-pointer-sb-left-arrow 110)
(defconst x-pointer-sb-right-arrow 112)
(defconst x-pointer-sb-up-arrow 114)
(defconst x-pointer-sb-v-double-arrow 116)
(defconst x-pointer-shuttle 118)
(defconst x-pointer-sizing 120)
(defconst x-pointer-spider 122)
(defconst x-pointer-spraycan 124)
(defconst x-pointer-star 126)
(defconst x-pointer-target 128)
(defconst x-pointer-tcross 130)
(defconst x-pointer-top-left-arrow 132)
(defconst x-pointer-top-left-corner 134)
(defconst x-pointer-top-right-corner 136)
(defconst x-pointer-top-side 138)
(defconst x-pointer-top-tee 140)
(defconst x-pointer-trek 142)
(defconst x-pointer-ul-angle 144)
(defconst x-pointer-umbrella 146)
(defconst x-pointer-ur-angle 148)
(defconst x-pointer-watch 150)
(defconst x-pointer-xterm 152)
(defconst x-pointer-invisible 65536) ;; This value is larger than a
                                     ;; CARD16, so it cannot be a
                                     ;; valid cursor.


;;;; Keysyms

(defun vendor-specific-keysyms (vendor)
  "Return the appropriate value of `system-key-alist' for VENDOR.
VENDOR is a string containing the name of the X Server's vendor,
as returned by `x-server-vendor'."
  (cond ((or (string-equal vendor "Hewlett-Packard Incorporated")
	     (string-equal vendor "Hewlett-Packard Company"))
	 '((  168 . mute-acute)
	   (  169 . mute-grave)
	   (  170 . mute-asciicircum)
	   (  171 . mute-diaeresis)
	   (  172 . mute-asciitilde)
	   (  175 . lira)
	   (  190 . guilder)
	   (  252 . block)
	   (  256 . longminus)
	   (65388 . reset)
	   (65389 . system)
	   (65390 . user)
	   (65391 . clearline)
	   (65392 . insertline)
	   (65393 . deleteline)
	   (65394 . insertchar)
	   (65395 . deletechar)
	   (65396 . backtab)
	   (65397 . kp-backtab)))
	;; Fixme: What about non-X11/NeWS sun server?
	((or (string-equal vendor "X11/NeWS - Sun Microsystems Inc.")
	     (string-equal vendor "X Consortium"))
	 '((392976 . f36)
	   (392977 . f37)
	   (393056 . req)
	   ;; These are for Sun under X11R6
	   (393072 . props)
	   (393073 . front)
	   (393074 . copy)
	   (393075 . open)
	   (393076 . paste)
	   (393077 . cut)))
	(t
	 ;; This is used by DEC's X server.
	 '((65280 . remove)))))

;; Latin-1
(let ((i 160))
  (while (< i 256)
    (puthash i i x-keysym-table)
    (setq i (1+ i))))

;; Table from Kuhn's proposed additions to the `KEYSYM Encoding'
;; appendix to the X protocol definition.  As indicated, some of these
;; have been corrected using information found in keysymdef.h which on
;; a typical system is installed at /usr/include/X11/keysymdef.h.  The
;; version used here is from xorgproto version 2019.1 found here:
;; https://gitlab.freedesktop.org/xorg/proto/xorgproto/blob/e0bba743ae7c549c58f92677b239ec7878548228/include/X11/keysymdef.h
(dolist
     (pair
      '(
	;; Latin-2
	(#x1a1 . ???)
	(#x1a2 . ???)
	(#x1a3 . ???)
	(#x1a5 . ???)
	(#x1a6 . ???)
	(#x1a9 . ???)
	(#x1aa . ???)
	(#x1ab . ???)
	(#x1ac . ???)
	(#x1ae . ???)
	(#x1af . ???)
	(#x1b1 . ???)
	(#x1b2 . ???)
	(#x1b3 . ???)
	(#x1b5 . ???)
	(#x1b6 . ???)
	(#x1b7 . ???)
	(#x1b9 . ???)
	(#x1ba . ???)
	(#x1bb . ???)
	(#x1bc . ???)
	(#x1bd . ???)
	(#x1be . ???)
	(#x1bf . ???)
	(#x1c0 . ???)
	(#x1c3 . ???)
	(#x1c5 . ???)
	(#x1c6 . ???)
	(#x1c8 . ???)
	(#x1ca . ???)
	(#x1cc . ???)
	(#x1cf . ???)
	(#x1d0 . ???)
	(#x1d1 . ???)
	(#x1d2 . ???)
	(#x1d5 . ???)
	(#x1d8 . ???)
	(#x1d9 . ???)
	(#x1db . ???)
	(#x1de . ???)
	(#x1e0 . ???)
	(#x1e3 . ???)
	(#x1e5 . ???)
	(#x1e6 . ???)
	(#x1e8 . ???)
	(#x1ea . ???)
	(#x1ec . ???)
	(#x1ef . ???)
	(#x1f0 . ???)
	(#x1f1 . ???)
	(#x1f2 . ???)
	(#x1f5 . ???)
	(#x1f8 . ???)
	(#x1f9 . ???)
	(#x1fb . ???)
	(#x1fe . ???)
	(#x1ff . ???)
	;; Latin-3
	(#x2a1 . ???)
	(#x2a6 . ???)
	(#x2a9 . ???)
	(#x2ab . ???)
	(#x2ac . ???)
	(#x2b1 . ???)
	(#x2b6 . ???)
	(#x2b9 . ???)
	(#x2bb . ???)
	(#x2bc . ???)
	(#x2c5 . ???)
	(#x2c6 . ???)
	(#x2d5 . ???)
	(#x2d8 . ???)
	(#x2dd . ???)
	(#x2de . ???)
	(#x2e5 . ???)
	(#x2e6 . ???)
	(#x2f5 . ???)
	(#x2f8 . ???)
	(#x2fd . ???)
	(#x2fe . ???)
	;; Latin-4
	(#x3a2 . ???)
	(#x3a3 . ???)
	(#x3a5 . ???)
	(#x3a6 . ???)
	(#x3aa . ???)
	(#x3ab . ???)
	(#x3ac . ???)
	(#x3b3 . ???)
	(#x3b5 . ???)
	(#x3b6 . ???)
	(#x3ba . ???)
	(#x3bb . ???)
	(#x3bc . ???)
	(#x3bd . ???)
	(#x3bf . ???)
	(#x3c0 . ???)
	(#x3c7 . ???)
	(#x3cc . ???)
	(#x3cf . ???)
	(#x3d1 . ???)
	(#x3d2 . ???)
	(#x3d3 . ???)
	(#x3d9 . ???)
	(#x3dd . ???)
	(#x3de . ???)
	(#x3e0 . ???)
	(#x3e7 . ???)
	(#x3ec . ???)
	(#x3ef . ???)
	(#x3f1 . ???)
	(#x3f2 . ???)
	(#x3f3 . ???)
	(#x3f9 . ???)
	(#x3fd . ???)
	(#x3fe . ???)
	(#x47e . ????)
	(#x4a1 . ????)
	(#x4a2 . ?\???)
	(#x4a3 . ?\???)
	(#x4a4 . ????)
	(#x4a5 . ????)
	(#x4a6 . ????)
	(#x4a7 . ????)
	(#x4a8 . ????)
	(#x4a9 . ????)
	(#x4aa . ????)
	(#x4ab . ????)
	(#x4ac . ????)
	(#x4ad . ????)
	(#x4ae . ????)
	(#x4af . ????)
	(#x4b0 . ????)
	(#x4b1 . ????)
	(#x4b2 . ????)
	(#x4b3 . ????)
	(#x4b4 . ????)
	(#x4b5 . ????)
	(#x4b6 . ????)
	(#x4b7 . ????)
	(#x4b8 . ????)
	(#x4b9 . ????)
	(#x4ba . ????)
	(#x4bb . ????)
	(#x4bc . ????)
	(#x4bd . ????)
	(#x4be . ????)
	(#x4bf . ????)
	(#x4c0 . ????)
	(#x4c1 . ????)
	(#x4c2 . ????)
	(#x4c3 . ????)
	(#x4c4 . ????)
	(#x4c5 . ????)
	(#x4c6 . ????)
	(#x4c7 . ????)
	(#x4c8 . ????)
	(#x4c9 . ????)
	(#x4ca . ????)
	(#x4cb . ????)
	(#x4cc . ????)
	(#x4cd . ????)
	(#x4ce . ????)
	(#x4cf . ????)
	(#x4d0 . ????)
	(#x4d1 . ????)
	(#x4d2 . ????)
	(#x4d3 . ????)
	(#x4d4 . ????)
	(#x4d5 . ????)
	(#x4d6 . ????)
	(#x4d7 . ????)
	(#x4d8 . ????)
	(#x4d9 . ????)
	(#x4da . ????)
	(#x4db . ????)
	(#x4dc . ????)
	(#x4dd . ????)
	(#x4de . ????)
	(#x4df . ????)
	;; Arabic
	(#x5ac . ???)
	(#x5bb . ???)
	(#x5bf . ???)
	(#x5c1 . ???)
	(#x5c2 . ???)
	(#x5c3 . ???)
	(#x5c4 . ???)
	(#x5c5 . ???)
	(#x5c6 . ???)
	(#x5c7 . ???)
	(#x5c8 . ???)
	(#x5c9 . ???)
	(#x5ca . ???)
	(#x5cb . ???)
	(#x5cc . ???)
	(#x5cd . ???)
	(#x5ce . ???)
	(#x5cf . ???)
	(#x5d0 . ???)
	(#x5d1 . ???)
	(#x5d2 . ???)
	(#x5d3 . ???)
	(#x5d4 . ???)
	(#x5d5 . ???)
	(#x5d6 . ???)
	(#x5d7 . ???)
	(#x5d8 . ???)
	(#x5d9 . ???)
	(#x5da . ???)
	(#x5e0 . ???)
	(#x5e1 . ???)
	(#x5e2 . ???)
	(#x5e3 . ???)
	(#x5e4 . ???)
	(#x5e5 . ???)
	(#x5e6 . ???)
	(#x5e7 . ???)
	(#x5e8 . ???)
	(#x5e9 . ???)
	(#x5ea . ???)
	(#x5eb . ???)
	(#x5ec . ???)
	(#x5ed . ???)
	(#x5ee . ???)
	(#x5ef . ???)
	(#x5f0 . ???)
	(#x5f1 . ???)
	(#x5f2 . ???)
	;; Cyrillic
	(#x680 . ???)
	(#x681 . ???)
	(#x682 . ???)
	(#x683 . ???)
	(#x684 . ???)
	(#x685 . ???)
	(#x686 . ???)
	(#x687 . ???)
	(#x688 . ???)
	(#x689 . ???)
	(#x68a . ???)
	(#x68c . ???)
	(#x68d . ???)
	(#x68e . ???)
	(#x68f . ???)
	(#x690 . ???)
	(#x691 . ???)
	(#x692 . ???)
	(#x693 . ???)
	(#x694 . ???)
	(#x695 . ???)
	(#x696 . ???)
	(#x697 . ???)
	(#x698 . ???)
	(#x699 . ???)
	(#x69a . ???)
	(#x69c . ???)
	(#x69d . ???)
	(#x69e . ???)
	(#x69f . ???)
	(#x6a1 . ???)
	(#x6a2 . ???)
	(#x6a3 . ???)
	(#x6a4 . ???)
	(#x6a5 . ???)
	(#x6a6 . ???)
	(#x6a7 . ???)
	(#x6a8 . ???)
	(#x6a9 . ???)
	(#x6aa . ???)
	(#x6ab . ???)
	(#x6ac . ???)
	(#x6ad . ???) ;; Source: keysymdef.h
	(#x6ae . ???)
	(#x6af . ???)
	(#x6b0 . ????)
	(#x6b1 . ???)
	(#x6b2 . ???)
	(#x6b3 . ???)
	(#x6b4 . ???)
	(#x6b5 . ???)
	(#x6b6 . ???)
	(#x6b7 . ???)
	(#x6b8 . ???)
	(#x6b9 . ???)
	(#x6ba . ???)
	(#x6bb . ???)
	(#x6bc . ???)
	(#x6bd . ???) ;; Source: keysymdef.h
	(#x6be . ???)
	(#x6bf . ???)
	(#x6c0 . ???)
	(#x6c1 . ???)
	(#x6c2 . ???)
	(#x6c3 . ???)
	(#x6c4 . ???)
	(#x6c5 . ???)
	(#x6c6 . ???)
	(#x6c7 . ???)
	(#x6c8 . ???)
	(#x6c9 . ???)
	(#x6ca . ???)
	(#x6cb . ???)
	(#x6cc . ???)
	(#x6cd . ???)
	(#x6ce . ???)
	(#x6cf . ???)
	(#x6d0 . ???)
	(#x6d1 . ???)
	(#x6d2 . ???)
	(#x6d3 . ???)
	(#x6d4 . ???)
	(#x6d5 . ???)
	(#x6d6 . ???)
	(#x6d7 . ???)
	(#x6d8 . ???)
	(#x6d9 . ???)
	(#x6da . ???)
	(#x6db . ???)
	(#x6dc . ???)
	(#x6dd . ???)
	(#x6de . ???)
	(#x6df . ???)
	(#x6e0 . ???)
	(#x6e1 . ???)
	(#x6e2 . ???)
	(#x6e3 . ???)
	(#x6e4 . ???)
	(#x6e5 . ???)
	(#x6e6 . ???)
	(#x6e7 . ???)
	(#x6e8 . ???)
	(#x6e9 . ???)
	(#x6ea . ???)
	(#x6eb . ???)
	(#x6ec . ???)
	(#x6ed . ???)
	(#x6ee . ???)
	(#x6ef . ???)
	(#x6f0 . ???)
	(#x6f1 . ???)
	(#x6f2 . ???)
	(#x6f3 . ???)
	(#x6f4 . ???)
	(#x6f5 . ???)
	(#x6f6 . ???)
	(#x6f7 . ???)
	(#x6f8 . ???)
	(#x6f9 . ???)
	(#x6fa . ???)
	(#x6fb . ???)
	(#x6fc . ???)
	(#x6fd . ???)
	(#x6fe . ???)
	(#x6ff . ???)
	;; Greek
	(#x7a1 . ???)
	(#x7a2 . ???)
	(#x7a3 . ???)
	(#x7a4 . ???)
	(#x7a5 . ???)
	(#x7a7 . ???)
	(#x7a8 . ???)
	(#x7a9 . ???)
	(#x7ab . ???)
	(#x7ae . ???)
	(#x7af . ????)
	(#x7b1 . ???)
	(#x7b2 . ???)
	(#x7b3 . ???)
	(#x7b4 . ???)
	(#x7b5 . ???)
	(#x7b6 . ???)
	(#x7b7 . ???)
	(#x7b8 . ???)
	(#x7b9 . ???)
	(#x7ba . ???)
	(#x7bb . ???)
	(#x7c1 . ???)
	(#x7c2 . ???)
	(#x7c3 . ???)
	(#x7c4 . ???)
	(#x7c5 . ???)
	(#x7c6 . ???)
	(#x7c7 . ???)
	(#x7c8 . ???)
	(#x7c9 . ???)
	(#x7ca . ???)
	(#x7cb . ???)
	(#x7cc . ???)
	(#x7cd . ???)
	(#x7ce . ???)
	(#x7cf . ???)
	(#x7d0 . ???)
	(#x7d1 . ???)
	(#x7d2 . ???)
	(#x7d4 . ???)
	(#x7d5 . ???)
	(#x7d6 . ???)
	(#x7d7 . ???)
	(#x7d8 . ???)
	(#x7d9 . ???)
	(#x7e1 . ???)
	(#x7e2 . ???)
	(#x7e3 . ???)
	(#x7e4 . ???)
	(#x7e5 . ???)
	(#x7e6 . ???)
	(#x7e7 . ???)
	(#x7e8 . ???)
	(#x7e9 . ???)
	(#x7ea . ???)
	(#x7eb . ???)
	(#x7ec . ???)
	(#x7ed . ???)
	(#x7ee . ???)
	(#x7ef . ???)
	(#x7f0 . ???)
	(#x7f1 . ???)
	(#x7f2 . ???)
	(#x7f3 . ???)
	(#x7f4 . ???)
	(#x7f5 . ???)
	(#x7f6 . ???)
	(#x7f7 . ???)
	(#x7f8 . ???)
	(#x7f9 . ???)
	 ;; Technical
	(#x8a1 . ????)
	(#x8a2 . ????)
	(#x8a3 . ????)
	(#x8a4 . ????)
	(#x8a5 . ????)
	(#x8a6 . ????)
	(#x8a7 . ????)
	(#x8a8 . ????)
	(#x8a9 . ????)
	(#x8aa . ????)
	(#x8ab . ????)
	(#x8ac . ????)
	(#x8ad . ????)
	(#x8ae . ????)
	(#x8af . ????)
	(#x8b0 . ????)
	(#x8bc . ????)
	(#x8bd . ????)
	(#x8be . ????)
	(#x8bf . ????)
	(#x8c0 . ????)
	(#x8c1 . ????)
	(#x8c2 . ????)
	(#x8c5 . ????)
	(#x8c8 . ????)
	(#x8c9 . ????)
	(#x8cd . ????)
	(#x8ce . ????)
	(#x8cf . ????)
	(#x8d6 . ????)
	(#x8da . ????)
	(#x8db . ????)
	(#x8dc . ????)
	(#x8dd . ????)
	(#x8de . ????)
	(#x8df . ????)
	(#x8ef . ????)
	(#x8f6 . ???)
	(#x8fb . ????)
	(#x8fc . ????)
	(#x8fd . ????)
	(#x8fe . ????)
	;; Special
	(#x9e0 . ????)
	(#x9e1 . ????)
	(#x9e2 . ????)
	(#x9e3 . ????)
	(#x9e4 . ????)
	(#x9e5 . ????)
	(#x9e8 . ????)
	(#x9e9 . ????)
	(#x9ea . ????)
	(#x9eb . ????)
	(#x9ec . ????)
	(#x9ed . ????)
	(#x9ee . ????)
	(#x9ef . ????)
	(#x9f0 . ????)
	(#x9f1 . ????)
	(#x9f2 . ????)
	(#x9f3 . ????)
	(#x9f4 . ????)
	(#x9f5 . ????)
	(#x9f6 . ????)
	(#x9f7 . ????)
	(#x9f8 . ????)
	;; Publishing
	(#xaa1 . ????)
	(#xaa2 . ????)
	(#xaa3 . ????)
	(#xaa4 . ????)
	(#xaa5 . ????)
	(#xaa6 . ????)
	(#xaa7 . ????)
	(#xaa8 . ????)
	(#xaa9 . ????)
	(#xaaa . ????)
	(#xaac . ????) ;; Source: keysymdef.h
	(#xaae . ????)
	(#xaaf . ????)
	(#xab0 . ????)
	(#xab1 . ????)
	(#xab2 . ????)
	(#xab3 . ????)
	(#xab4 . ????)
	(#xab5 . ????)
	(#xab6 . ????)
	(#xab7 . ????)
	(#xab8 . ????)
	(#xabb . ????)
	;; In keysymdef.h, the keysyms 0xabc and 0xabe are listed as
	;; U+27E8 and U+27E9 respectively.  However, the parentheses
	;; indicate that these mappings are deprecated legacy keysyms
	;; that are either not one-to-one or semantically unclear.  In
	;; order to not introduce any incompatibility with possible
	;; existing workflows that expect these keysyms to map as they
	;; currently do, to 0x2329 and 0x232a, respectively, they are
	;; left as they are.  In particular, PuTTY is known to agree
	;; with this mapping.
	(#xabc . ????)
	(#xabd . ?.) ;; Source: keysymdef.h
	(#xabe . ????)
	(#xac3 . ????)
	(#xac4 . ????)
	(#xac5 . ????)
	(#xac6 . ????)
	(#xac9 . ????)
	(#xaca . ????)
	(#xacc . ????)
	(#xacd . ????)
	(#xace . ????)
	(#xacf . ????)
	(#xad0 . ????)
	(#xad1 . ????)
	(#xad2 . ????)
	(#xad3 . ????)
	(#xad4 . ????)
	(#xad5 . ????) ;; Source: keysymdef.h
	(#xad6 . ????)
	(#xad7 . ????)
	(#xad9 . ????)
	(#xadb . ????)
	(#xadc . ????)
	(#xadd . ????)
	(#xade . ????)
	(#xadf . ????)
	(#xae0 . ????)
	(#xae1 . ????)
	(#xae2 . ????)
	(#xae3 . ????)
	(#xae4 . ????)
	(#xae5 . ????)
	(#xae6 . ????)
	(#xae7 . ????)
	(#xae8 . ????)
	(#xae9 . ????)
	(#xaea . ????)
	(#xaeb . ????)
	(#xaec . ????)
	(#xaed . ????)
	(#xaee . ????)
	(#xaf0 . ????)
	(#xaf1 . ????)
	(#xaf2 . ????)
	(#xaf3 . ????)
	(#xaf4 . ????)
	(#xaf5 . ????)
	(#xaf6 . ????)
	(#xaf7 . ????)
	(#xaf8 . ????)
	(#xaf9 . ????)
	(#xafa . ????)
	(#xafb . ????)
	(#xafc . ????)
	(#xafd . ????)
	(#xafe . ????)
	;; APL
	(#xba3 . ?<)
	(#xba6 . ?>)
	(#xba8 . ????)
	(#xba9 . ????)
	(#xbc0 . ???)
	;; Source for #xbc2: keysymdef.h.  Note that the
	;; `KEYSYM Encoding' appendix to the X protocol definition is
	;; incorrect.
	(#xbc2 . ????)
	(#xbc3 . ????)
	(#xbc4 . ????)
	(#xbc6 . ?_)
	(#xbca . ????)
	(#xbcc . ????)
	;; Source for #xbce: keysymdef.h.  Note that the
	;; `KEYSYM Encoding' appendix to the X protocol definition is
	;; incorrect.
	(#xbce . ????)
	(#xbcf . ????)
	(#xbd3 . ????)
	(#xbd6 . ????)
	(#xbd8 . ????)
	(#xbda . ????)
	;; Source for #xbdc and #xbfc: keysymdef.h.  Note that the
	;; `KEYSYM Encoding' appendix to the X protocol definition is
	;; incorrect.
	(#xbdc . ????)
	(#xbfc . ????)
	;; Hebrew
	(#xcdf . ????)
	(#xce0 . ???)
	(#xce1 . ???)
	(#xce2 . ???)
	(#xce3 . ???)
	(#xce4 . ???)
	(#xce5 . ???)
	(#xce6 . ???)
	(#xce7 . ???)
	(#xce8 . ???)
	(#xce9 . ???)
	(#xcea . ???)
	(#xceb . ???)
	(#xcec . ???)
	(#xced . ???)
	(#xcee . ???)
	(#xcef . ???)
	(#xcf0 . ???)
	(#xcf1 . ???)
	(#xcf2 . ???)
	(#xcf3 . ???)
	(#xcf4 . ???)
	(#xcf5 . ???)
	(#xcf6 . ???)
	(#xcf7 . ???)
	(#xcf8 . ???)
	(#xcf9 . ???)
	(#xcfa . ???)
	;; Thai
	(#xda1 . ????)
	(#xda2 . ????)
	(#xda3 . ????)
	(#xda4 . ????)
	(#xda5 . ????)
	(#xda6 . ????)
	(#xda7 . ????)
	(#xda8 . ????)
	(#xda9 . ????)
	(#xdaa . ????)
	(#xdab . ????)
	(#xdac . ????)
	(#xdad . ????)
	(#xdae . ????)
	(#xdaf . ????)
	(#xdb0 . ????)
	(#xdb1 . ????)
	(#xdb2 . ????)
	(#xdb3 . ????)
	(#xdb4 . ????)
	(#xdb5 . ????)
	(#xdb6 . ????)
	(#xdb7 . ????)
	(#xdb8 . ????)
	(#xdb9 . ????)
	(#xdba . ????)
	(#xdbb . ????)
	(#xdbc . ????)
	(#xdbd . ????)
	(#xdbe . ????)
	(#xdbf . ????)
	(#xdc0 . ????)
	(#xdc1 . ????)
	(#xdc2 . ????)
	(#xdc3 . ????)
	(#xdc4 . ????)
	(#xdc5 . ????)
	(#xdc6 . ????)
	(#xdc7 . ????)
	(#xdc8 . ????)
	(#xdc9 . ????)
	(#xdca . ????)
	(#xdcb . ????)
	(#xdcc . ????)
	(#xdcd . ????)
	(#xdce . ????)
	(#xdcf . ????)
	(#xdd0 . ????)
	(#xdd1 . ????)
	(#xdd2 . ????)
	(#xdd3 . ????)
	(#xdd4 . ????)
	(#xdd5 . ????)
	(#xdd6 . ????)
	(#xdd7 . ????)
	(#xdd8 . ????)
	(#xdd9 . ????)
	(#xdda . ????)
	(#xddf . ????)
	(#xde0 . ????)
	(#xde1 . ????)
	(#xde2 . ????)
	(#xde3 . ????)
	(#xde4 . ????)
	(#xde5 . ????)
	(#xde6 . ????)
	(#xde7 . ????)
	(#xde8 . ????)
	(#xde9 . ????)
	(#xdea . ????)
	(#xdeb . ????)
	(#xdec . ????)
	(#xded . ????)
	(#xdf0 . ????)
	(#xdf1 . ????)
	(#xdf2 . ????)
	(#xdf3 . ????)
	(#xdf4 . ????)
	(#xdf5 . ????)
	(#xdf6 . ????)
	(#xdf7 . ????)
	(#xdf8 . ????)
	(#xdf9 . ????)
	;; Korean
	(#xea1 . ????)
	(#xea2 . ????)
	(#xea3 . ????)
	(#xea4 . ????)
	(#xea5 . ????)
	(#xea6 . ????)
	(#xea7 . ????)
	(#xea8 . ????)
	(#xea9 . ????)
	(#xeaa . ????)
	(#xeab . ????)
	(#xeac . ????)
	(#xead . ????)
	(#xeae . ????)
	(#xeaf . ????)
	(#xeb0 . ????)
	(#xeb1 . ????)
	(#xeb2 . ????)
	(#xeb3 . ????)
	(#xeb4 . ????)
	(#xeb5 . ????)
	(#xeb6 . ????)
	(#xeb7 . ????)
	(#xeb8 . ????)
	(#xeb9 . ????)
	(#xeba . ????)
	(#xebb . ????)
	(#xebc . ????)
	(#xebd . ????)
	(#xebe . ????)
	(#xebf . ????)
	(#xec0 . ????)
	(#xec1 . ????)
	(#xec2 . ????)
	(#xec3 . ????)
	(#xec4 . ????)
	(#xec5 . ????)
	(#xec6 . ????)
	(#xec7 . ????)
	(#xec8 . ????)
	(#xec9 . ????)
	(#xeca . ????)
	(#xecb . ????)
	(#xecc . ????)
	(#xecd . ????)
	(#xece . ????)
	(#xecf . ????)
	(#xed0 . ????)
	(#xed1 . ????)
	(#xed2 . ????)
	(#xed3 . ????)
	(#xed4 . ????)
	(#xed5 . ????)
	(#xed6 . ????)
	(#xed7 . ????)
	(#xed8 . ????)
	(#xed9 . ????)
	(#xeda . ????)
	(#xedb . ????)
	(#xedc . ????)
	(#xedd . ????)
	(#xede . ????)
	(#xedf . ????)
	(#xee0 . ????)
	(#xee1 . ????)
	(#xee2 . ????)
	(#xee3 . ????)
	(#xee4 . ????)
	(#xee5 . ????)
	(#xee6 . ????)
	(#xee7 . ????)
	(#xee8 . ????)
	(#xee9 . ????)
	(#xeea . ????)
	(#xeeb . ????)
	(#xeec . ????)
	(#xeed . ????)
	(#xeee . ????)
	(#xeef . ????)
	(#xef0 . ????)
	(#xef1 . ????)
	(#xef2 . ????)
	(#xef3 . ????)
	(#xef4 . ????)
	(#xef5 . ????)
	(#xef6 . ????)
	(#xef7 . ????)
	(#xef8 . ????)
	(#xef9 . ????)
	(#xefa . ????)
	(#xeff . ????)
	;; Latin-5
	;; Latin-6
	;; Latin-7
	;; Latin-8
	;; Latin-9
	(#x13bc . ???)
	(#x13bd . ???)
	(#x13be . ???)
	;; Currency
	(#x20a0 . ????)
	(#x20a1 . ????)
	(#x20a2 . ????)
	(#x20a3 . ????)
	(#x20a4 . ????)
	(#x20a5 . ????)
	(#x20a6 . ????)
	(#x20a7 . ????)
	(#x20a8 . ????)
	(#x20aa . ????)
	(#x20ab . ????)
	(#x20ac . ????)))
  (puthash (car pair) (cdr pair) x-keysym-table))

;; The following keysym codes for graphics are listed in the document
;; as not having unicodes available:

;; #x08b1	TOP LEFT SUMMATION	Technical
;; #x08b2	BOTTOM LEFT SUMMATION	Technical
;; #x08b3	TOP VERTICAL SUMMATION CONNECTOR	Technical
;; #x08b4	BOTTOM VERTICAL SUMMATION CONNECTOR	Technical
;; #x08b5	TOP RIGHT SUMMATION	Technical
;; #x08b6	BOTTOM RIGHT SUMMATION	Technical
;; #x08b7	RIGHT MIDDLE SUMMATION	Technical
;; #x0aac	SIGNIFICANT BLANK SYMBOL	Publish
;; #x0abd	DECIMAL POINT	Publish
;; #x0abf	MARKER	Publish
;; #x0acb	TRADEMARK SIGN IN CIRCLE	Publish
;; #x0ada	HEXAGRAM	Publish
;; #x0aff	CURSOR	Publish
;; #x0dde	THAI MAIHANAKAT	Thai

;; However, keysymdef.h does have mappings for #x0aac and #x0abd, which
;; are used above.


;;;; Selections

;; Arrange for the kill and yank functions to set and check the clipboard.

(defun x-clipboard-yank ()
  "Insert the clipboard contents, or the last stretch of killed text."
  (declare (obsolete clipboard-yank "25.1"))
  (interactive "*")
  (let ((clipboard-text (gui--selection-value-internal 'CLIPBOARD))
	(select-enable-clipboard t))
    (when (and clipboard-text (> (length clipboard-text) 0))
      ;; Avoid asserting ownership of CLIPBOARD, which will cause
      ;; `gui-selection-value' to return nil in the future.
      ;; (bug#56273)
      (let ((select-enable-clipboard nil))
        (kill-new clipboard-text)))
    (yank)))

(declare-function accelerate-menu "xmenu.c" (&optional frame) t)

(defun x-menu-bar-open (&optional frame)
  "Open the menu bar if it is shown.
`popup-menu' is used if it is off."
  (interactive "i")
  (cond
   ((and (not (zerop (or (frame-parameter nil 'menu-bar-lines) 0)))
	 (fboundp 'accelerate-menu))
    (accelerate-menu frame))
   (t
    (popup-menu (mouse-menu-bar-map) last-nonmenu-event))))


;;; Window system initialization.

(defun x-win-suspend-error ()
  "Report an error when a suspend is attempted.
This returns an error if any Emacs frames are X frames."
  ;; Don't allow suspending if any of the frames are X frames.
  (if (memq 'x (mapcar #'window-system (frame-list)))
      (error "Cannot suspend Emacs while an X GUI frame exists")))

(defvar x-initialized nil
  "Non-nil if the X window system has been initialized.")

(declare-function x-open-connection "xfns.c"
		  (display &optional xrm-string must-succeed))
(declare-function x-server-max-request-size "xfns.c" (&optional terminal))
(declare-function x-get-resource "frame.c"
		  (attribute class &optional component subclass))
(declare-function x-parse-geometry "frame.c" (string))
(defvar x-resource-name)
(defvar x-display-name)
(defvar x-command-line-resources)

(cl-defmethod window-system-initialization (&context (window-system x)
                                            &optional display)
  "Initialize Emacs for X frames and open the first connection to an X server."
  (cl-assert (not x-initialized))

  ;; Make sure we have a valid resource name.
  (or (stringp x-resource-name)
      (let (i)
	(setq x-resource-name (copy-sequence invocation-name))

	;; Change any . or * characters in x-resource-name to hyphens,
	;; so as not to choke when we use it in X resource queries.
	(while (setq i (string-match "[.*]" x-resource-name))
	  (aset x-resource-name i ?-))))

  (x-open-connection (or display
			 (setq x-display-name (or (getenv "DISPLAY" (selected-frame))
						  (getenv "DISPLAY"))))
		     x-command-line-resources
		     ;; Exit Emacs with fatal error if this fails and we
		     ;; are the initial display.
		     (eq initial-window-system 'x))

  ;; Create the default fontset.
  (create-default-fontset)

  ;; Create the standard fontset.
  (condition-case err
	(create-fontset-from-fontset-spec standard-fontset-spec t)
    (error (display-warning
	    'initialization
	    (format "Creation of the standard fontset failed: %s" err)
	    :error)))

  ;; Create fontset specified in X resources "Fontset-N" (N is 0, 1, ...).
  (create-fontset-from-x-resource)

  ;; Set scroll bar mode to right if set by X resources. Default is left.
  (if (equal (x-get-resource "verticalScrollBars" "ScrollBars") "right")
      (customize-set-variable 'scroll-bar-mode 'right))

  ;; Apply a geometry resource to the initial frame.  Put it at the end
  ;; of the alist, so that anything specified on the command line takes
  ;; precedence.
  (let* ((res-geometry (x-get-resource "geometry" "Geometry"))
	 parsed)
    (if res-geometry
	(progn
	  (setq parsed (x-parse-geometry res-geometry))
	  ;; If the resource specifies a position,
	  ;; call the position and size "user-specified".
	  (if (or (assq 'top parsed) (assq 'left parsed))
	      (setq parsed (cons '(user-position . t)
				 (cons '(user-size . t) parsed))))
	  ;; All geometry parms apply to the initial frame.
	  (setq initial-frame-alist (append initial-frame-alist parsed))
	  ;; The size parms apply to all frames.  Don't set it if there are
	  ;; sizes there already (from command line).
	  (if (and (assq 'height parsed)
		   (not (assq 'height default-frame-alist)))
	      (setq default-frame-alist
		    (cons (cons 'height (cdr (assq 'height parsed)))
			  default-frame-alist)))
	  (if (and (assq 'width parsed)
		   (not (assq 'width default-frame-alist)))
	      (setq default-frame-alist
		    (cons (cons 'width (cdr (assq 'width parsed)))
			  default-frame-alist))))))

  ;; Set x-selection-timeout, measured in milliseconds.
  (let ((res-selection-timeout (x-get-resource "selectionTimeout"
					       "SelectionTimeout")))
    (setq x-selection-timeout
	  (if res-selection-timeout
	      (string-to-number res-selection-timeout)
	    5000)))

  ;; Don't let Emacs suspend under X.
  (add-hook 'suspend-hook 'x-win-suspend-error)

  ;; During initialization, we defer sending size hints to the window
  ;; manager, because that can induce a race condition:
  ;; https://lists.gnu.org/r/emacs-devel/2008-10/msg00033.html
  ;; Send the size hints once initialization is done.
  (add-hook 'after-init-hook 'x-wm-set-size-hint)

  ;; Turn off window-splitting optimization; X is usually fast enough
  ;; that this is only annoying.
  (setq split-window-keep-point t)

  ;; Motif direct handling of f10 wasn't working right,
  ;; So temporarily we've turned it off in lwlib-Xm.c
  ;; and turned the Emacs f10 back on.
  ;; ;; Motif normally handles f10 itself, so don't try to handle it a second time.
  ;; (if (featurep 'motif)
  ;;     (global-set-key [f10] 'ignore))

  ;; Enable CLIPBOARD copy/paste through menu bar commands.
  (menu-bar-enable-clipboard)

  ;; ;; Override Paste so it looks at CLIPBOARD first.
  ;; (define-key menu-bar-edit-menu [paste]
  ;;   (append '(menu-item "Paste" x-clipboard-yank
  ;; 			:enable (not buffer-read-only)
  ;; 			:help "Paste (yank) text most recently cut/copied")
  ;; 	    nil))

  (x-apply-session-resources)
  (setq x-initialized t))

(declare-function x-own-selection-internal "xselect.c"
		  (selection value &optional frame))
(declare-function x-disown-selection-internal "xselect.c"
		  (selection &optional time-object terminal))
(declare-function x-selection-owner-p "xselect.c"
		  (&optional selection terminal))
(declare-function x-selection-exists-p "xselect.c"
		  (&optional selection terminal))
(declare-function x-get-selection-internal "xselect.c"
		  (selection-symbol target-type &optional time-stamp terminal))

(add-to-list 'display-format-alist '("\\`.*:[0-9]+\\(\\.[0-9]+\\)?\\'" . x))
(cl-defmethod handle-args-function (args &context (window-system x))
  (x-handle-args args))

(cl-defmethod frame-creation-function (params &context (window-system x))
  (x-create-frame-with-faces params))

(cl-defmethod gui-backend-set-selection (selection value
                                         &context (window-system x))
  (if value (x-own-selection-internal selection value)
    (x-disown-selection-internal selection)))

(cl-defmethod gui-backend-selection-owner-p (selection
                                             &context (window-system x))
  (x-selection-owner-p selection))

(cl-defmethod gui-backend-selection-exists-p (selection
                                              &context (window-system x))
  (x-selection-exists-p selection))

(cl-defmethod gui-backend-get-selection (selection-symbol target-type
                                         &context (window-system x)
                                         &optional time-stamp terminal)
  (x-get-selection-internal selection-symbol target-type
                            time-stamp terminal))

;; Initiate drag and drop
(add-hook 'after-make-frame-functions 'x-dnd-init-frame)
(define-key special-event-map [drag-n-drop] 'x-dnd-handle-drag-n-drop-event)

(defcustom x-gtk-stock-map
  (mapcar (lambda (arg)
	    (cons (purecopy (car arg)) (purecopy (cdr arg))))
  '(
    ("etc/images/new" . ("document-new" "gtk-new"))
    ("etc/images/open" . ("document-open" "gtk-open"))
    ("etc/images/diropen" . "gtk-directory")
    ("etc/images/close" . ("window-close" "gtk-close"))
    ("etc/images/save" . ("document-save" "gtk-save"))
    ("etc/images/saveas" . ("document-save-as" "gtk-save-as"))
    ("etc/images/undo" . ("edit-undo" "gtk-undo"))
    ("etc/images/cut" . ("edit-cut" "gtk-cut"))
    ("etc/images/copy" . ("edit-copy" "gtk-copy"))
    ("etc/images/paste" . ("edit-paste" "gtk-paste"))
    ("etc/images/search" . ("edit-find" "gtk-find"))
    ("etc/images/print" . ("document-print" "gtk-print"))
    ("etc/images/preferences" . ("preferences-system" "gtk-preferences"))
    ("etc/images/help" . ("help-browser" "gtk-help"))
    ("etc/images/left-arrow" . ("go-previous" "gtk-go-back"))
    ("etc/images/right-arrow" . ("go-next" "gtk-go-forward"))
    ("etc/images/home" . ("go-home" "gtk-home"))
    ("etc/images/jump-to" . ("go-jump" "gtk-jump-to"))
    ("etc/images/index" . ("gtk-search" "gtk-index"))
    ("etc/images/exit" . ("application-exit" "gtk-quit"))
    ("etc/images/cancel" . "gtk-cancel")
    ("etc/images/info" . ("dialog-information" "gtk-info"))
    ("etc/images/bookmark_add" . "n:bookmark_add")
    ;; Used in Gnus and/or MH-E:
    ("etc/images/attach" . ("mail-attachment" "gtk-attach"))
    ("etc/images/connect" . "gtk-connect")
    ("etc/images/contact" . "gtk-contact")
    ("etc/images/delete" . ("edit-delete" "gtk-delete"))
    ("etc/images/describe" . ("document-properties" "gtk-properties"))
    ("etc/images/disconnect" . "gtk-disconnect")
    ;; ("etc/images/exit" . "gtk-exit")
    ("etc/images/lock-broken" . "gtk-lock_broken")
    ("etc/images/lock-ok" . "gtk-lock_ok")
    ("etc/images/lock" . "gtk-lock")
    ("etc/images/next-page" . "gtk-next-page")
    ("etc/images/refresh" . ("view-refresh" "gtk-refresh"))
    ("etc/images/search-replace" . "edit-find-replace")
    ("etc/images/sort-ascending" . ("view-sort-ascending" "gtk-sort-ascending"))
    ("etc/images/sort-column-ascending" . "gtk-sort-column-ascending")
    ("etc/images/sort-criteria" . "gtk-sort-criteria")
    ("etc/images/sort-descending" . ("view-sort-descending"
				     "gtk-sort-descending"))
    ("etc/images/sort-row-ascending" . "gtk-sort-row-ascending")
    ("etc/images/spell" . ("tools-check-spelling" "gtk-spell-check"))
    ("images/gnus/toggle-subscription" . "gtk-task-recurring")
    ("images/mail/compose" . ("mail-message-new" "gtk-mail-compose"))
    ("images/mail/copy" . "gtk-mail-copy")
    ("images/mail/forward" . "gtk-mail-forward")
    ("images/mail/inbox" . "gtk-inbox")
    ("images/mail/move" . "gtk-mail-move")
    ("images/mail/not-spam" . "gtk-not-spam")
    ("images/mail/outbox" . "gtk-outbox")
    ("images/mail/reply-all" . "gtk-mail-reply-to-all")
    ("images/mail/reply" . "gtk-mail-reply")
    ("images/mail/save-draft" . "gtk-mail-handling")
    ("images/mail/send" . ("mail-send" "gtk-mail-send"))
    ("images/mail/spam" . "gtk-spam")
    ;; Used for GDB Graphical Interface
    ("images/gud/break" . "gtk-no")
    ("images/gud/recstart" . ("media-record" "gtk-media-record"))
    ("images/gud/recstop" . ("media-playback-stop" "gtk-media-stop"))
    ;; No themed versions available:
    ;; mail/preview (combining stock_mail and stock_zoom)
    ;; mail/save    (combining stock_mail, stock_save and stock_convert)
    ))
  "How icons for tool bars are mapped to Gtk+ stock items.
Emacs must be compiled with the Gtk+ toolkit for this to have any effect.
A value that begins with n: denotes a named icon instead of a stock icon."
  :version "22.2"
  :type '(choice (repeat
		  (choice symbol
			  (cons (string :tag "Emacs icon")
				(choice (group (string :tag "Named")
					       (string :tag "Stock"))
					(string :tag "Stock/named"))))))
  :group 'x)

(defcustom icon-map-list '(x-gtk-stock-map)
  "A list of alists that map icon file names to stock/named icons.
The alists are searched in the order they appear.  The first match is used.
The keys in the alists are file names without extension and with two directory
components.  For example, to map /usr/share/emacs/22.1.1/etc/images/open.xpm
to stock item gtk-open, use:

  (\"etc/images/open\" . \"gtk-open\")

Themes also have named icons.  To map to one of those, use n: before the name:

  (\"etc/images/diropen\" . \"n:system-file-manager\")

The list elements are either the symbol name for the alist or the
alist itself.

If you don't want stock icons, set the variable to nil."
  :version "22.2"
  :type '(choice (const :tag "Don't use stock icons" nil)
		 (repeat (choice symbol
				 (cons (string :tag "Emacs icon")
				       (string :tag "Stock/named")))))
  :group 'x)

(defcustom x-display-cursor-at-start-of-preedit-string nil
  "If non-nil, display the cursor at the start of any pre-edit text."
  :version "29.1"
  :type 'boolean
  :group 'x)

(defconst x-gtk-stock-cache (make-hash-table :weakness t :test 'equal))

(defun x-gtk-map-stock (file)
  "Map icon with file name FILE to a Gtk+ stock name.
This uses `icon-map-list' to map icon file names to stock icon names."
  (when (stringp file)
    (or (gethash file x-gtk-stock-cache)
	(puthash
	 file
	 (save-match-data
	   (let* ((file-sans (file-name-sans-extension file))
		  (key (and (string-match "/\\([^/]+/[^/]+/[^/]+$\\)"
					  file-sans)
			    (match-string 1 file-sans)))
		  (icon-map icon-map-list)
		  elem value)
	     (while (and (null value) icon-map)
	       (setq elem (car icon-map)
		     value (assoc-string (or key file-sans)
					 (if (symbolp elem)
					     (symbol-value elem)
					   elem))
		     icon-map (cdr icon-map)))
	     (and value (cdr value))))
	 x-gtk-stock-cache))))

(global-set-key [XF86WakeUp] 'ignore)


(defvar x-preedit-overlay nil
  "The overlay currently used to display preedit text from a compose sequence.")

;; With some input methods, text gets inserted before Emacs is told to
;; remove any preedit text that was displayed, which causes both the
;; preedit overlay and the text to be visible for a brief period of
;; time.  This pre-command-hook clears the overlay before any command
;; and should be set whenever a preedit overlay is visible.
(defun x-clear-preedit-text ()
  "Clear the pre-edit overlay and remove itself from pre-command-hook.
This function should be installed in `pre-command-hook' whenever
preedit text is displayed."
  (when x-preedit-overlay
    (delete-overlay x-preedit-overlay)
    (setq x-preedit-overlay nil))
  (remove-hook 'pre-command-hook #'x-clear-preedit-text))

(defun x-preedit-text (event)
  "Display preedit text from a compose sequence in EVENT.
EVENT is a preedit-text event."
  (interactive "e")
  (when x-preedit-overlay
    (delete-overlay x-preedit-overlay)
    (setq x-preedit-overlay nil)
    (remove-hook 'pre-command-hook #'x-clear-preedit-text))
  (when (nth 1 event)
    (let ((string (propertize (nth 1 event) 'face '(:underline t))))
      (setq x-preedit-overlay (make-overlay (point) (point)))
      (add-hook 'pre-command-hook #'x-clear-preedit-text)
      (overlay-put x-preedit-overlay 'window (selected-window))
      (overlay-put x-preedit-overlay 'before-string
                   (if x-display-cursor-at-start-of-preedit-string
                       (propertize string 'cursor t)
                     string)))))

(define-key special-event-map [preedit-text] 'x-preedit-text)

(defvaralias 'x-gtk-use-system-tooltips 'use-system-tooltips)

(declare-function x-internal-focus-input-context "xfns.c" (focus))

(defun x-gtk-use-native-input-watcher (_symbol newval &rest _ignored)
  "Variable watcher for `x-gtk-use-native-input'.
If NEWVAL is non-nil, focus the GTK input context of focused
frames on all displays."
  (when (and (featurep 'gtk)
             (eq (framep (selected-frame)) 'x))
    (x-internal-focus-input-context newval)))

(add-variable-watcher 'x-gtk-use-native-input
                      #'x-gtk-use-native-input-watcher)

(defun x-dnd-movement (_frame position)
  "Handle movement to POSITION during drag-and-drop."
  (dnd-handle-movement position))

(defun x-device-class (name)
  "Return the device class of NAME.
Users should not call this function; see `device-class' instead."
  (and name
       (let ((downcased-name (downcase name)))
         (cond
          ((string-match-p "XTEST" name) 'test)
          ((string= "Virtual core pointer" name) 'core-pointer)
          ((string= "Virtual core keyboard" name) 'core-keyboard)
          ((string-match-p "eraser" downcased-name) 'eraser)
          ((string-match-p " pad" downcased-name) 'pad)
          ((or (or (string-match-p "wacom" downcased-name)
                   (string-match-p "pen" downcased-name))
               (string-match-p "stylus" downcased-name))
           'pen)
          ((or (string-prefix-p "xwayland-touch:" name)
               (string-match-p "touchscreen" downcased-name))
           'touchscreen)
          ((or (string-match-p "trackpoint" downcased-name)
               (string-match-p "stick" downcased-name))
           'trackpoint)
          ((or (string-match-p "mouse" downcased-name)
               (string-match-p "optical" downcased-name)
               (string-match-p "pointer" downcased-name))
           'mouse)
          ((string-match-p "cursor" downcased-name) 'puck)
          ((or (string-match-p "keyboard" downcased-name)
               ;; One of my cheap keyboards is really named this...
               (string= name "USB USB Keykoard"))
           'keyboard)
          ((string-match-p "button" downcased-name) 'power-button)
          ((string-match-p "touchpad" downcased-name) 'touchpad)
          ((or (string-match-p "midi" downcased-name)
               (string-match-p "piano" downcased-name))
           'piano)
          ((or (string-match-p "wskbd" downcased-name) ; NetBSD/OpenBSD
               (and (string-match-p "/dev" downcased-name)
                    (string-match-p "kbd" downcased-name)))
           'keyboard)))))

(setq x-dnd-movement-function #'x-dnd-movement)
(setq x-dnd-unsupported-drop-function #'x-dnd-handle-unsupported-drop)

(defvar x-input-coding-function)

(defun x-get-input-coding-system (x-locale)
  "Return a coding system for the locale X-LOCALE.
Return a coding system that is able to decode text sent with the
X input method locale X-LOCALE, or nil if no coding system was
found."
  (if (equal x-locale "C")
      ;; Treat the C locale specially, as it means "ascii" under X.
      'ascii
    (let ((locale (locale-translate (downcase x-locale))))
      (or (locale-name-match locale locale-preferred-coding-systems)
	  (when locale
	    (if (string-match "\\.\\([^@]+\\)" locale)
	        (locale-charset-to-coding-system
	         (match-string 1 locale))))
          (let ((language-name
                 (locale-name-match locale locale-language-names)))
            (and (consp language-name) (cdr language-name)))))))

(setq x-input-coding-function #'x-get-input-coding-system)

(provide 'x-win)
(provide 'term/x-win)

;;; x-win.el ends here
