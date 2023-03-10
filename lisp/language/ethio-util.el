;;; ethio-util.el --- utilities for Ethiopic	-*- coding: utf-8-emacs; lexical-binding: t; -*-

;; Copyright (C) 1997-1998, 2002-2023 Free Software Foundation, Inc.
;; Copyright (C) 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005,
;;   2006, 2007, 2008, 2009, 2010, 2011
;;   National Institute of Advanced Industrial Science and Technology (AIST)
;;   Registration Number H14PRO021
;; Copyright (C) 2005, 2006
;;   National Institute of Advanced Industrial Science and Technology (AIST)
;;   Registration Number: H15PRO110

;; Keywords: mule, multilingual, Ethiopic

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

;; Author: TAKAHASHI Naoto <ntakahas@m17n.org>

;;; Commentary:

;; Note: This file includes several codepoints outside of the Unicode
;; 0..#x10FFFF range, which are characters that were not unified into
;; Unicode.  Therefore, this file is encoded in utf-8-emacs, because
;; UTF-8 cannot encode such codepoints.  We include these codepoints
;; literally in the file to have them displayed by suitable fonts,
;; which makes maintenance easier.

;;; Code:

(require 'robin)

;; Information for exiting Ethiopic environment.
(defvar exit-ethiopic-environment-data nil)

;;;###autoload
(defun setup-ethiopic-environment-internal ()
  (let ((key-bindings '((" " . ethio-insert-space)
			([?\S- ] . ethio-insert-ethio-space)
			;; ([?\C-'] . ethio-gemination)
			([f3] . ethio-fidel-to-sera-buffer)
			([S-f3] . ethio-fidel-to-sera-region)
			([C-f3] . ethio-fidel-to-sera-marker)
			([f4] . ethio-sera-to-fidel-buffer)
			([S-f4] . ethio-sera-to-fidel-region)
			([C-f4] . ethio-sera-to-fidel-marker)
			;; ([S-f5] . ethio-toggle-punctuation)
			([S-f6] . ethio-modify-vowel)
			([S-f7] . ethio-replace-space)
			;; ([S-f8] . ethio-input-special-character) ; deprecated
			([C-f9] . ethio-toggle-space)
			([S-f9] . ethio-replace-space) ; as requested
			))
	kb)
    (while key-bindings
      (setq kb (car (car key-bindings)))
      (setq exit-ethiopic-environment-data
	    (cons (cons kb (global-key-binding kb))
		  exit-ethiopic-environment-data))
      (global-set-key kb (cdr (car key-bindings)))
      (setq key-bindings (cdr key-bindings))))

  (add-hook 'find-file-hook 'ethio-find-file)
  (add-hook 'write-file-functions 'ethio-write-file)
  (add-hook 'after-save-hook 'ethio-find-file))

(defun exit-ethiopic-environment ()
  "Exit Ethiopic language environment."
  (while exit-ethiopic-environment-data
    (global-set-key (car (car exit-ethiopic-environment-data))
		    (cdr (car exit-ethiopic-environment-data)))
    (setq exit-ethiopic-environment-data
	  (cdr exit-ethiopic-environment-data)))

  (remove-hook 'find-file-hook 'ethio-find-file)
  (remove-hook 'write-file-functions 'ethio-write-file)
  (remove-hook 'after-save-hook 'ethio-find-file))

;;
;; ETHIOPIC UTILITY FUNCTIONS
;;

;; If the filename ends in ".sera", editing is done in fidel
;; but file I/O is done in SERA.
;;
;; If the filename ends in ".java", editing is done in fidel
;; but file I/O is done in the \uXXXX style, where XXXX is
;; the Unicode codepoint for the Ethiopic character.
;;
;; If the filename ends in ".tex", editing is done in fidel
;; but file I/O is done in EthioTeX format.

;;
;; users' preference
;;

(defgroup ethiopic nil
  "Options for writing Ethiopic."
  :version "28.1"
  :group 'languages)

(defcustom ethio-primary-language 'tigrigna
  "Symbol that defines the primary language in SERA --> FIDEL conversion.
FIDEL is the Amharic alphabet; SERA (System for Ethiopic Representation
in ASCII) is the Latin representation of Ethiopic script.
The value should be one of: `tigrigna', `amharic' or `english'."
  :version "28.1"
  :type '(choice (const :tag "Tigrigna" tigrigna)
                 (const :tag "Amharic" amharic)
                 (const :tag "English" english)))

(defcustom ethio-secondary-language 'english
  "Symbol that defines the secondary language in SERA --> FIDEL conversion.
FIDEL is the Amharic alphabet; SERA (System for Ethiopic Representation
in ASCII) is the Latin representation of Ethiopic script.
The value should be one of: `tigrigna', `amharic' or `english'."
  :version "28.1"
  :type '(choice (const :tag "Tigrigna" tigrigna)
                 (const :tag "Amharic" amharic)
                 (const :tag "English" english)))

(defcustom ethio-use-colon-for-colon nil
  "Non-nil means associate ASCII colon with Ethiopic colon.
If nil, associate ASCII colon with Ethiopic word separator, i.e., two
vertically stacked dots.  All SERA <--> FIDEL converters refer this
variable.
FIDEL is the Amharic alphabet; SERA (System for Ethiopic Representation
in ASCII) is the Latin representation of Ethiopic script."
  :version "28.1"
  :type 'boolean)

(defcustom ethio-use-three-dot-question nil
  "If non-nil, associate ASCII question mark with Ethiopic question mark.
The Ethiopic old style question mark is three vertically stacked dots.
If nil, associate ASCII question mark with Ethiopic stylized question
mark.  All SERA <--> FIDEL converters refer this variable.
FIDEL is the Amharic alphabet; SERA (System for Ethiopic Representation
in ASCII) is the Latin representation of Ethiopic script."
  :version "28.1"
  :type 'boolean)

(defcustom ethio-quote-vowel-always nil
  "Non-nil means always put an apostrophe before an isolated vowel.
This happens in FIDEL --> SERA conversions.  Isolated vowels at
word beginning do not get an apostrophe put before them.
If nil, put an apostrophe only between a 6th-form consonant and an
isolated vowel.
FIDEL is the Amharic alphabet; SERA (System for Ethiopic Representation
in ASCII) is the Latin representation of Ethiopic script."
  :version "28.1"
  :type 'boolean)

(defcustom ethio-W-sixth-always nil
  "Non-nil means convert the Wu-form of a 12-form consonant to \"W'\".
This is instead of \"Wu\" in FIDEL --> SERA conversion.
FIDEL is the Amharic alphabet; SERA (System for Ethiopic Representation
in ASCII) is the Latin representation of Ethiopic script."
  :version "28.1"
  :type 'boolean)

(defcustom ethio-numeric-reduction 0
  "Degree of reduction in converting Ethiopic digits into Arabic digits.
Should be 0, 1 or 2.
For example, ({10}{9}{100}{80}{7}) is converted into:
    \\=`10\\=`9\\=`100\\=`80\\=`7  if `ethio-numeric-reduction' is 0,
    \\=`109100807	    if `ethio-numeric-reduction' is 1,
    \\=`10900807	    if `ethio-numeric-reduction' is 2."
  :version "28.1"
  :type 'integer)

(defcustom ethio-java-save-lowercase nil
  "Non-nil means save Ethiopic characters in lowercase hex numbers to Java files.
If nil, use uppercases."
  :version "28.1"
  :type 'boolean)


(defun ethio-prefer-amharic-p ()
  (or (eq ethio-primary-language 'amharic)
      (and (not (eq ethio-primary-language 'tigrigna))
	   (eq ethio-secondary-language 'amharic))))

(defun ethio-prefer-amharic (arg)
  (if arg
      (progn
	(robin-modify-package "ethiopic-sera" "'a" ????)
	(robin-modify-package "ethiopic-sera" "a" "???")
	(robin-modify-package "ethiopic-sera" "'A" ????)
	(robin-modify-package "ethiopic-sera" "A" "???"))
    (robin-modify-package "ethiopic-sera" "'A" ????)
    (robin-modify-package "ethiopic-sera" "A" "???")
    (robin-modify-package "ethiopic-sera" "'a" ????)
    (robin-modify-package "ethiopic-sera" "a" "???")))

(defun ethio-use-colon-for-colon (arg)
  (if arg
      (progn
	(robin-modify-package "ethiopic-sera" ":" ????)
	(robin-modify-package "ethiopic-sera" "`:" ????))
    (robin-modify-package "ethiopic-sera" " : " ????)
    (robin-modify-package "ethiopic-sera" ":" "???")
    (robin-modify-package "ethiopic-sera" "-:" ????)))

(defun ethio-use-three-dot-question (arg)
  (if arg
      (progn
	(robin-modify-package "ethiopic-sera" "?" ????)
	(robin-modify-package "ethiopic-sera" "`?" ??))
    (robin-modify-package "ethiopic-sera" "?" ??)
    (robin-modify-package "ethiopic-sera" "`?" ????)))

(defun ethio-adjust-robin ()
  (ethio-prefer-amharic (ethio-prefer-amharic-p))
  (ethio-use-colon-for-colon ethio-use-colon-for-colon)
  (ethio-use-three-dot-question ethio-use-three-dot-question))

(add-hook 'robin-activate-hook 'ethio-adjust-robin)

;;
;; SERA to FIDEL
;;

;;;###autoload
(defun ethio-sera-to-fidel-buffer (&optional secondary force)
  "Convert the current buffer from SERA to FIDEL.

FIDEL is the Amharic alphabet; SERA (System for Ethiopic Representation
in ASCII) is the Latin representation of Ethiopic script.
The variable `ethio-primary-language' specifies the primary
language and `ethio-secondary-language' specifies the secondary.

If the 1st optional argument SECONDARY is non-nil, assume the
buffer begins with the secondary language; otherwise with the
primary language.

If the 2nd optional argument FORCE is non-nil, perform conversion
even if the buffer is read-only.

See also the descriptions of the variables
`ethio-use-colon-for-colon' and `ethio-use-three-dot-question'."

  (interactive "P")
  (ethio-sera-to-fidel-region (point-min) (point-max) secondary force))

;; To avoid byte-compiler warnings.  It should never be set globally.
(defvar ethio-sera-being-called-by-w3)
;; This variable will be bound by some third-party package.
(defvar sera-being-called-by-w3)

;;;###autoload
(defun ethio-sera-to-fidel-region (begin end &optional secondary force)
  "Convert the characters in region from SERA to FIDEL.

FIDEL is the Amharic alphabet; SERA (System for Ethiopic Representation
in ASCII) is the Latin representation of Ethiopic script.
The variable `ethio-primary-language' specifies the primary
language and `ethio-secondary-language' specifies the secondary.

If the 3rd argument SECONDARY is given and non-nil, assume the
region begins with the secondary language; otherwise with the
primary language.

If the 4th argument FORCE is given and non-nil, perform
conversion even if the buffer is read-only.

See also the descriptions of the variables
`ethio-use-colon-for-colon' and `ethio-use-three-dot-question'."

  (interactive "r\nP")
  (if (and buffer-read-only
	   (not force)
	   (not (y-or-n-p "Buffer is read-only.  Force to convert? ")))
      (error ""))

  (let ((ethio-primary-language ethio-primary-language)
	(ethio-secondary-language ethio-secondary-language)
	;; The above two variables may be changed temporarily by tilde
	;; escapes during conversion.  We bind them to the variables
	;; of the same names so that the original values are restored
	;; when this function exits.
	(buffer-read-only nil)
	(lang (if secondary ethio-secondary-language ethio-primary-language))
	ret)

    (ethio-use-colon-for-colon ethio-use-colon-for-colon)
    (ethio-use-three-dot-question ethio-use-three-dot-question)

    (save-restriction
      (narrow-to-region begin end)
      (goto-char (point-min))
      (while (not (eobp))
	(setq ret
	      (cond
	       ((eq lang 'amharic)
		(ethio-prefer-amharic t)
		(ethio-sera-to-fidel-region-ethio 'amharic))
	       ((eq lang 'tigrigna)
		(ethio-prefer-amharic nil)
		(ethio-sera-to-fidel-region-ethio 'tigrigna))
	       (t
		(ethio-sera-to-fidel-region-noethio))))
	(setq lang
	      (if (eq ret 'toggle)
		  (if (eq lang ethio-primary-language)
		      ethio-secondary-language
		    ethio-primary-language)
		ret)))))

  ;; Restore user's preference.
  (ethio-adjust-robin))

(defun ethio-sera-to-fidel-region-noethio ()
  "Return next language as symbol: amharic, tigrigna, toggle or nil."
  (let (lflag)
    (cond

     ;; No more "\", i.e. nothing to do.
     ((not (search-forward "\\" nil 0))
      nil)

     ;; Hereafter point is put after a "\".
     ;; First delete that "\", then check the following chars.

     ;; A language flag.
     ((progn (delete-char -1) (setq lflag (ethio-process-language-flag)))
      lflag)

     ;; "\\" : leave the second "\" and continue in the same language.
     ((= (following-char) ?\\)
      (forward-char 1)
      nil)

     ;; "\ " : delete the following " " and toggle the language.
     ((= (following-char) 32)
      (delete-char 1)
      'toggle)

     ;; A  "\" but not a special sequence: simply toggle the language.
     (t
      'toggle))))

(defun ethio-sera-to-fidel-region-ethio (lang)
  "Return next language as symbol: amharic, tigrigna, toggle or nil."
  (save-restriction
    (narrow-to-region
     (point)
     (if (re-search-forward "\\(`[1-9][0-9]*\\)\\|[\\<&]" nil t)
	 (match-beginning 0)
       (point-max)))
    (robin-convert-region (point-min) (point-max) "ethiopic-sera")
    (goto-char (point-max)))

  (let (lflag)
    (cond
     ((= (following-char) ?`)
      (delete-char 1)
      (ethio-process-digits)
      lang)

     ((looking-at "[<&]")
      (if (or (and (boundp 'ethio-sera-being-called-by-w3)
		   ethio-sera-being-called-by-w3)
	      (and (boundp 'sera-being-called-by-w3)
		   sera-being-called-by-w3))
	  (search-forward (if (= (following-char) ?<) ">" ";") nil 0)
	(forward-char 1))
      lang)

     ((eobp)
      nil)

     ;; Now we must be looking at a "\".
     ;; First delete that "\", then check the following chars.

     ((progn (delete-char 1) (= (following-char) 32))
      (delete-char 1)
      'toggle)

     ((looking-at "[,.;:'`?\\]+")
      (goto-char (match-end 0))
      lang)

     ((/= (following-char) ?~)
      'toggle)

     ;; Now we must be looking at a "~".

     ((setq lflag (ethio-process-language-flag))
      lflag)

     ;; Delete the following "~" and check the following chars.

     ((progn (delete-char 1) (looking-at "! ?"))
      (replace-match "")
      (if (re-search-forward "\\\\~! ?" nil 0)
	  (replace-match ""))
      lang)

     ((looking-at "-: ?")
      (replace-match "")
      (ethio-use-colon-for-colon t)
      lang)

     ((looking-at "`: ?")
      (replace-match "")
      (ethio-use-colon-for-colon nil)
      lang)

     ((looking-at "`| ?")
      (replace-match "")
      (ethio-use-three-dot-question t)
      lang)

     ((looking-at "\\? ?")
      (replace-match "")
      (ethio-use-three-dot-question nil)
      lang)

     ;; Unknown tilde escape.  Recover the deleted chars.
     (t
      (insert "\\~")
      lang))))

(defun ethio-process-language-flag nil
  "Process a language flag of the form \"~lang\" or \"~lang1~lang2\".

If looking at \"~lang1~lang2\", set `ethio-primary-language' and
`ethio-secondary-language' based on \"lang1\" and \"lang2\".
Then delete the language flag \"~lang1~lang2\" from the buffer.
Return value is the new primary language.

If looking at \"~lang\", delete that language flag \"~lang\" from
the buffer and return that language.  In this case
`ethio-primary-language' and `ethio-secondary-language' are left
unchanged.

If an unsupported language flag is found, just return nil without
changing anything."

  (let (lang1 lang2)
    (cond

     ;; ~lang1~lang2
     ((and (looking-at
	    "~\\([a-z][a-z][a-z]?\\)~\\([a-z][a-z][a-z]?\\)[ \t\n\\]")
	   (setq lang1 (ethio-flag-to-language (match-string 1)))
	   (setq lang2 (ethio-flag-to-language (match-string 2))))
      (setq ethio-primary-language lang1
	    ethio-secondary-language lang2)
      (delete-region (point) (match-end 2))
      (if (= (following-char) 32)
	  (delete-char 1))
      ethio-primary-language)

     ;; ~lang
     ((and (looking-at "~\\([a-z][a-z][a-z]?\\)[ \t\n\\]")
	   (setq lang1 (ethio-flag-to-language (match-string 1))))
      (delete-region (point) (match-end 1))
      (if (= (following-char) 32)
	  (delete-char 1))
      lang1)

     ;; otherwise
     (t
      nil))))

(defun ethio-flag-to-language (flag)
  (cond
   ((or (string= flag "en") (string= flag "eng")) 'english)
   ((or (string= flag "ti") (string= flag "tir")) 'tigrigna)
   ((or (string= flag "am") (string= flag "amh")) 'amharic)
   (t nil)))

(defun ethio-process-digits nil
  "Convert Arabic digits to Ethiopic digits."
  (let (ch z)
    (while (and (>= (setq ch (following-char)) ?1)
		(<= ch ?9))
      (delete-char 1)

      ;; count up following zeros
      (setq z 0)
      (while (= (following-char) ?0)
	(delete-char 1)
	(setq z (1+ z)))

      (cond

       ;; first digit is 10, 20, ..., or 90
       ((= (mod z 2) 1)
	(insert (aref [???? ???? ???? ???? ???? ???? ???? ???? ????] (- ch ?1)))
	(setq z (1- z)))

       ;; first digit is 2, 3, ..., or 9
       ((/= ch ?1)
	(insert (aref [???? ???? ???? ???? ???? ???? ???? ????] (- ch ?2))))

       ;; single 1
       ((= z 0)
	(insert "???")))

      ;; 100
      (if (= (mod z 4) 2)
	  (insert "???"))

      ;; 10000
      (insert-char ???? (/ z 4)))))

;;;###autoload
(defun ethio-sera-to-fidel-marker (&optional force)
  "Convert regions surrounded by \"<sera>\" and \"</sera>\" from SERA to FIDEL.
FIDEL is the Amharic alphabet; SERA (System for Ethiopic Representation
in ASCII) is the Latin representation of Ethiopic script.
Assume that each region begins with `ethio-primary-language'.
The markers \"<sera>\" and \"</sera>\" themselves are not deleted."
  (interactive "P")
  (if (and buffer-read-only
	   (not force)
	   (not (y-or-n-p "Buffer is read-only.  Force to convert? ")))
      (error ""))
  (save-excursion
    (goto-char (point-min))
    (while (search-forward "<sera>" nil t)
      (ethio-sera-to-fidel-region
       (point)
       (if (search-forward "</sera>" nil t)
	   (match-beginning 0)
	 (point-max))
       nil
       'force))))

;;
;; FIDEL to SERA
;;

(defun ethio-language-to-flag (lang)
  (cond
   ((eq lang 'english) "eng")
   ((eq lang 'tigrigna) "tir")
   ((eq lang 'amharic) "amh")
   (t "")))

;;;###autoload
(defun ethio-fidel-to-sera-buffer (&optional secondary force)
  "Convert all the FIDEL characters in the current buffer to the SERA format.
FIDEL is the Amharic alphabet; SERA (System for Ethiopic Representation
in ASCII) is the Latin representation of Ethiopic script.
The variable `ethio-primary-language' specifies the primary
language and `ethio-secondary-language' specifies the secondary.

If the 1st optional argument SECONDARY is non-nil, try to convert the
region so that it begins with the secondary language; otherwise with the
primary language.

If the 2nd optional argument FORCE is non-nil, convert even if the
buffer is read-only.

See also the descriptions of the variables
`ethio-use-colon-for-colon', `ethio-use-three-dot-question',
`ethio-quote-vowel-always' and `ethio-numeric-reduction'."

  (interactive "P")
  (ethio-fidel-to-sera-region (point-min) (point-max) secondary force))

;;;###autoload
(defun ethio-fidel-to-sera-region (begin end &optional secondary force)
  "Convert all the FIDEL characters in the region to the SERA format.

FIDEL is the Amharic alphabet; SERA (System for Ethiopic Representation
in ASCII) is the Latin representation of Ethiopic script.
The variable `ethio-primary-language' specifies the primary
language and `ethio-secondary-language' specifies the secondary.

If the 3rd argument SECONDARY is given and non-nil, convert
the region so that it begins with the secondary language; otherwise with
the primary language.

If the 4th argument FORCE is given and non-nil, convert even if the
buffer is read-only.

See also the descriptions of the variables
`ethio-use-colon-for-colon', `ethio-use-three-dot-question',
`ethio-quote-vowel-always' and `ethio-numeric-reduction'."

  (interactive "r\nP")
  (if (and buffer-read-only
	   (not force)
	   (not (y-or-n-p "Buffer is read-only.  Force to convert? ")))
      (error ""))

  (save-restriction
    (narrow-to-region begin end)

    (let ((buffer-read-only nil)
	  (mode (if secondary
		    ethio-secondary-language
		  ethio-primary-language))
	  (flag (if (ethio-prefer-amharic-p) "\\~amh " "\\~tir "))
	  p ch)

      (goto-char (point-min))
      (ethio-adjust-robin)
      (unless (eq mode 'english)
	(setq mode 'ethiopic))
      (if (and (eq mode 'english) (looking-at "\\ce"))
	  (setq mode 'ethiopic))
      (if (and (eq mode 'ethiopic) (looking-at "\\Ce"))
	  (setq mode 'english))
      (insert (if (eq mode 'english) "\\~eng " flag))

      (while (not (eobp))

	(if (eq mode 'english)
	    (progn
	      (if (re-search-forward "\\(\\ce\\|\\\\\\)" nil 0)
		  (forward-char -1))
	      (cond
	       ((eq (following-char) ?\\)
		(insert "\\")
		(forward-char 1))
	       ((looking-at "\\ce")
		(insert flag)
		(setq mode 'ethiopic))))

	  ;; If we reach here, mode is ethiopic.
	  (setq p (point))
	  (if (re-search-forward "[a-z,.;:'`?\\<&]" nil 0)
	      (forward-char -1))
	  (save-restriction
	    (narrow-to-region p (point))
	    (robin-invert-region (point-min) (point-max) "ethiopic-sera")

	    ;; ethio-quote-vowel-always
	    (goto-char (point-min))
	    (while (re-search-forward "'[eauio]" nil t)
	      (save-excursion
		(forward-char -2)
		(setq ch (preceding-char))
		(if (or (and (>= ch ?a) (<= ch ?z))
			(and (>= ch ?A) (<= ch ?Z)))
		    (if (and (not ethio-quote-vowel-always)
			     (memq ch '(?e ?a ?u ?i ?o ?E ?A ?I)))
			(delete-char 1))
		  (delete-char 1))))

	    ;; ethio-W-sixth-always
	    (unless ethio-W-sixth-always
	      (goto-char (point-min))
	      (while (search-forward "W'" nil t)
		(delete-char -1)
		(insert "u")))

	    ;; ethio-numeric-reduction
	    (when (> ethio-numeric-reduction 0)
	      (goto-char (point-min))
	      (while (re-search-forward "\\([0-9]\\)`\\([0-9]\\)" nil t)
		(replace-match "\\1\\2")
		(forward-char -1)))
	    (when (= ethio-numeric-reduction 2)
	      (goto-char (point-min))
	      (while (re-search-forward "\\([0-9]\\)1\\(0+\\)" nil t)
		(replace-match "\\1\\2")))

	    (goto-char (point-max)))

	  (cond
	   ((looking-at "[a-z]")
	    (insert"\\~eng ")
	    (setq mode 'english))
	   ((looking-at "[,.;:'`\\]+")
	    (insert "\\")
	    (goto-char (1+ (match-end 0))))
	   ((= (following-char) ??)
	    (if ethio-use-three-dot-question
		(insert "\\"))
	    (forward-char 1))
	   ((looking-at "[<&]")
	    (if (or (and (boundp 'ethio-sera-being-called-by-w3)
			 ethio-sera-being-called-by-w3)
		    (and (boundp 'sera-being-called-by-w3)
			 sera-being-called-by-w3))
		(search-forward (if (= (following-char) ?<) ">" "&") nil 0)
	      (forward-char 1)))))))))

;;;###autoload
(defun ethio-fidel-to-sera-marker (&optional force)
  "Convert the regions surrounded by \"<sera>\" and \"</sera>\" from FIDEL to SERA.
FIDEL is the Amharic alphabet; SERA (System for Ethiopic Representation
in ASCII) is the Latin representation of Ethiopic script.
The markers \"<sera>\" and \"</sera>\" themselves are not deleted."

  (interactive "P")
  (if (and buffer-read-only
	   (not force)
	   (not (y-or-n-p "Buffer is read-only.  Force to convert? ")))
      (error ""))
  (save-excursion
    (goto-char (point-min))
    (while (search-forward "<sera>" nil t)
      (ethio-fidel-to-sera-region
       (point)
       (if (search-forward "</sera>" nil t)
	   (match-beginning 0)
	 (point-max))
       nil
       'force))))

;;
;; vowel modification
;;

;;;###autoload
(defun ethio-modify-vowel nil
  "Modify the vowel of the FIDEL that is under the cursor.
FIDEL is the Amharic/Ethiopic alphabet."
  (interactive)
  (ethio-adjust-robin)
  (let ((consonant (ethio-get-consonant (following-char)))
	vowel)
    (if (null consonant)
	(error "")			; not an Ethiopic char
      (setq vowel (read-char "Modify vowel to: "))
      (delete-char 1)
      (if (and (string= consonant "'") (= vowel ?W))
	  (insert ????)
	(save-restriction
	  (narrow-to-region (point) (point))
	  (insert consonant vowel)
	  (robin-convert-region (point-min) (point-max) "ethiopic-sera"))))))

(defun ethio-get-consonant (ch)
  "Return the consonant part of CH's SERA spelling in ethiopic-sera.
SERA (System for Ethiopic Representation in ASCII) is the Latin
representation of Ethiopic script."
  (let ((sera (get-char-code-property ch 'ethiopic-sera)))
    (cond
     ((null sera) nil)
     ((= ch ????) "'")			; Only this has two vowel letters.
     (t (with-temp-buffer
	  (insert sera)
	  (if (memq (preceding-char) '(?e ?u ?i ?a ?o ?E ?I ?A ?'))
	      (delete-char -1))
	  (buffer-substring (point-min) (point-max)))))))

;;
;; space replacement
;;

;;;###autoload
(defun ethio-replace-space (ch begin end)
  "Replace ASCII spaces with Ethiopic word separators in the region.

In the specified region, replace word separators surrounded by two
Ethiopic characters, depending on the first argument CH, which should
be 1, 2, or 3.

If CH = 1, word separator will be replaced with an ASCII space.
If CH = 2, with two ASCII spaces.
If CH = 3, with the Ethiopic colon-like word separator.

The 2nd and 3rd arguments BEGIN and END specify the region."

  (interactive "*cReplace spaces to: 1 (sg col), 2 (dbl col), 3 (Ethiopic)\nr")
  (if (not (memq ch '(?1 ?2 ?3)))
      (error ""))
  (save-excursion
    (save-restriction
      (narrow-to-region begin end)

      (cond
       ((= ch ?1)
	;; an Ethiopic word separator --> an ASCII space
	(goto-char (point-min))
	(while (search-forward "???" nil t)
	  (replace-match " "))

	;; two ASCII spaces between Ethiopic characters --> an ASCII space
	(goto-char (point-min))
	(while (re-search-forward "\\(\\ce\\)  \\(\\ce\\)" nil t)
	  (replace-match "\\1 \\2")
	  (forward-char -1)))

       ((= ch ?2)
	;; An Ethiopic word separator --> two ASCII spaces
	(goto-char (point-min))
	(while (search-forward "???" nil t)
	  (replace-match "  "))

	;; An ASCII space between Ethiopic characters --> two ASCII spaces
	(goto-char (point-min))
	(while (re-search-forward "\\(\\ce\\) \\(\\ce\\)" nil t)
	  (replace-match "\\1  \\2")
	  (forward-char -1)))

       (t
	;; One or two ASCII spaces between Ethiopic characters
	;;   --> An Ethiopic word separator
	(goto-char (point-min))
	(while (re-search-forward "\\(\\ce\\)  ?\\(\\ce\\)" nil t)
	  (replace-match "\\1???\\2")
	  (forward-char -1))

	;; Three or more ASCII spaces between Ethiopic characters
	;;   --> An Ethiopic word separator + (N - 2) ASCII spaces
	(goto-char (point-min))
	(while (re-search-forward "\\(\\ce\\)  \\( +\\ce\\)" nil t)
	  (replace-match "\\1???\\2")
	  (forward-char -1)))))))

;;
;; special icons
;;

;; This function is deprecated.
;;;###autoload
(defun ethio-input-special-character (arg)
  "This function is deprecated."
  (interactive "*cInput number: 1.????  2.????  3.????  4.????  5.????")
  (cond
   ((eq arg ?1)
    (insert "????"))
   ((eq arg ?2)
    (insert "????"))
   ((eq arg ?3)
    (insert "????"))
   ((eq arg ?4)
    (insert "????"))
   ((eq arg ?5)
    (insert "????"))
   (t
    (error ""))))

;;
;; TeX support
;;

;;;###autoload
(defun ethio-fidel-to-tex-buffer nil
  "Convert each FIDEL characters in the current buffer into a fidel-tex command.
FIDEL is the Amharic/Ethiopic alphabet."
  (interactive)
  (let ((buffer-read-only nil)
	comp)

    ;; Special treatment for geminated characters.
    ;; Geminated characters la", etc. change into \geminateG{\laG}, etc.
    (goto-char (point-min))
    (while (re-search-forward "???\\|????" nil t)
      (setq comp (find-composition (match-beginning 0)))
      (if (null comp)
	  (replace-match "\\\\geminateG{}" t)
	(decompose-region (car comp) (cadr comp))
	(delete-char -1)
	(forward-char -1)
	(insert "\\geminateG{")
	(forward-char 1)
	(insert "}")))

    ;; Special Ethiopic punctuation.
    (goto-char (point-min))
    (while (re-search-forward "\\ce[??.?]\\|??\\ce" nil t)
      (let ((ch (preceding-char)))
        (cond
         ((eq ch ?\??)
	  (delete-char -1)
	  (insert "\\rquoteG"))
         ((eq ch ?.)
	  (delete-char -1)
	  (insert "\\dotG"))
         ((eq ch ??)
	  (delete-char -1)
	  (insert "\\qmarkG"))
         (t
	  (forward-char -1)
	  (delete-char -1)
	  (insert "\\lquoteG")
	  (forward-char 1)))))

    ;; Ethiopic characters to TeX macros
    (robin-invert-region (point-min) (point-max) "ethiopic-tex")

    (goto-char (point-min))
    (set-buffer-modified-p nil)))

;;;###autoload
(defun ethio-tex-to-fidel-buffer ()
  "Convert fidel-tex commands in the current buffer into FIDEL chars.
FIDEL is the Amharic/Ethiopic alphabet."
  (interactive)
  (let ((inhibit-read-only t)
	;; (p) (ch)
	)

    ;; TeX macros to Ethiopic characters
    (robin-convert-region (point-min) (point-max) "ethiopic-tex")

    ;; compose geminated characters
    (goto-char (point-min))
    (while (re-search-forward "\\\\geminateG{\\(\\ce?\\)}" nil t)
      (replace-match "\\1???"))

    ;; remove redundant braces, if any
    (goto-char (point-min))
    (while (re-search-forward "{\\(\\ce\\)}" nil t)
      (replace-match "\\1"))

    (goto-char (point-min))
    (set-buffer-modified-p nil)))

;;
;; Java support
;;

;;;###autoload
(defun ethio-fidel-to-java-buffer nil
  "Convert Ethiopic characters in the buffer into the Java escape sequences.

Each escape sequence is of the form \\uXXXX, where XXXX is the
character's codepoint (in hex) in Unicode.

If `ethio-java-save-lowercase' is non-nil, use [0-9a-f].
Otherwise, [0-9A-F]."
  (let ((ucode))

    (goto-char (point-min))
    (while (re-search-forward "[???-???]" nil t)
      (setq ucode (preceding-char))
      (delete-char -1)
      (insert
       (format (if ethio-java-save-lowercase "\\u%4x" "\\u%4X")
	       ucode)))))

;;;###autoload
(defun ethio-java-to-fidel-buffer nil
  "Convert the Java escape sequences in the buffer into Ethiopic characters."
  (let ((case-fold-search t)
	(ucode))
    (goto-char (point-min))
    (while (re-search-forward "\\\\u\\([0-9a-f][0-9a-f][0-9a-f][0-9a-f]\\)" nil t)
      (setq ucode (read (concat "#x" (match-string 1))))
      (when (and (>= ucode #x1200) (<= ucode #x137f))
	(replace-match (char-to-string ucode))))))

;;
;; file I/O hooks
;;

;;;###autoload
(defun ethio-find-file nil
  "Transliterate file content into Ethiopic depending on filename suffix.
If the file-name extension is \".sera\", convert from SERA to FIDEL.
If the file-name extension is \".html\", convert regions enclosed
by \"<sera>..</sera>\" from SERA to FIDEL.
If the file-name extension is \".tex\", convert fidel-tex commands
to FIDEL characters.
If the file-name extension is \".java\", convert Java escape sequences
to FIDEL characters.

FIDEL is the Amharic alphabet; SERA (System for Ethiopic Representation
in ASCII) is the Latin representation of Ethiopic script."
  (cond

   ((string-match "\\.sera$" (buffer-file-name))
    (save-excursion
      (ethio-sera-to-fidel-buffer nil 'force)
      (set-buffer-modified-p nil)))

   ((string-match "\\.html$" (buffer-file-name))
    (let ((ethio-sera-being-called-by-w3 t))
      (save-excursion
	(ethio-sera-to-fidel-marker 'force)
	(goto-char (point-min))
	(while (re-search-forward "&[lr]aquo;" nil t)
	  (if (= (char-after (1+ (match-beginning 0))) ?l)
	      (replace-match "??")
	    (replace-match "??")))
	(set-buffer-modified-p nil))))

   ((string-match "\\.tex$" (buffer-file-name))
    (save-excursion
      (ethio-tex-to-fidel-buffer)
      (set-buffer-modified-p nil)))

   ((string-match "\\.java$" (buffer-file-name))
    (save-excursion
      (ethio-java-to-fidel-buffer)
      (set-buffer-modified-p nil)))

   (t
    nil)))

;;;###autoload
(defun ethio-write-file nil
  "Transliterate Ethiopic characters to ASCII depending on the file extension.
If the file-name extension is \".sera\", convert from FIDEL to SERA.
If the file-name extension is \".html\", convert FIDEL characters to
SERA regions enclosed by \"<sera>..</sera>\".
If the file-name extension is \".tex\", convert FIDEL characters
to fidel-tex commands.
If the file-name extension is \".java\", convert FIDEL characters to
Java escape sequences.

FIDEL is the Amharic alphabet; SERA (System for Ethiopic Representation
in ASCII) is the Latin representation of Ethiopic script."
  (cond

   ((string-match "\\.sera$" (buffer-file-name))
    (save-excursion
      (ethio-fidel-to-sera-buffer nil 'force)
      (goto-char (point-min))
      (ethio-record-user-preference)
      (set-buffer-modified-p nil)))

   ((string-match "\\.html$" (buffer-file-name))
    (save-excursion
      (let ((ethio-sera-being-called-by-w3 t))
	(ethio-fidel-to-sera-marker 'force)
	(goto-char (point-min))
	(while (re-search-forward "[????]" nil t)
	  (replace-match (if (= (preceding-char) ???) "&laquo;" "&raquo;")))
	(goto-char (point-min))
	(if (search-forward "<sera>" nil t)
	    (ethio-record-user-preference))
	(set-buffer-modified-p nil))))

   ((string-match "\\.tex$" (buffer-file-name))
    (save-excursion
      (ethio-fidel-to-tex-buffer)
      (set-buffer-modified-p nil)))

   ((string-match "\\.java$" (buffer-file-name))
    (save-excursion
      (ethio-fidel-to-java-buffer)
      (set-buffer-modified-p nil)))

   (t
    nil)))

(defun ethio-record-user-preference nil
  (insert (if ethio-use-colon-for-colon "\\~-: " "\\~`: ")
	  (if ethio-use-three-dot-question "\\~`| " "\\~? ")))

;;
;; Ethiopic word separator vs. ASCII space
;;

(defvar-local ethio-prefer-ascii-space t)

(defun ethio-toggle-space nil
  "Toggle ASCII space and Ethiopic separator for keyboard input."
  (interactive)
  (setq ethio-prefer-ascii-space
	(not ethio-prefer-ascii-space)))

(defun ethio-insert-space (arg)
  "Insert ASCII spaces or Ethiopic word separators depending on context.

If the current word separator (indicated in mode-line) is the ASCII space,
insert an ASCII space.  With ARG, insert that many ASCII spaces.

If the current word separator is the colon-like Ethiopic word
separator and the point is preceded by `an Ethiopic punctuation mark
followed by zero or more ASCII spaces', then insert also an ASCII
space.  With ARG, insert that many ASCII spaces.

Otherwise, insert a colon-like Ethiopic word separator.  With ARG, insert that
many Ethiopic word separators."

  (interactive "*p")
  (cond
   (ethio-prefer-ascii-space
    (insert-char 32 arg))
   ((save-excursion
      (skip-chars-backward " ")
      (memq (preceding-char)
	    '(???? ???? ???? ???? ???? ???? ???? ???? ????? ????? ????? ????? ?????)))
    (insert-char 32 arg))
   (t
    (insert-char ???? arg))))

;;;###autoload
(defun ethio-insert-ethio-space (arg)
  "Insert the Ethiopic word delimiter (the colon-like character).
With ARG, insert that many delimiters."
  (interactive "*p")
  (insert-char ???? arg))

;;
;; Gemination
;;

;;;###autoload
(defun ethio-composition-function (pos _to _font-object string _direction)
  (setq pos (1- pos))
  (let ((pattern "\\ce\\(???\\|????\\)"))
    (if string
	(if (and (>= pos 0)
		 (eq (string-match pattern string pos) pos))
	    (prog1 (match-end 0)
	      (compose-string string pos (match-end 0))))
      (if (>= pos (point-min))
	  (progn
	    (goto-char pos)
	    (if (looking-at pattern)
		(prog1 (match-end 0)
		  (compose-region pos (match-end 0)))))))))

;; This function is not used any more.
(defun ethio-gemination nil
  "Compose the character before point with the Ethiopic gemination mark.
If the character is already composed, decompose it and remove the gemination
mark."
  (interactive "*")
  (let ((ch (preceding-char)))
    (cond
     ((and (= ch ?????) (find-composition (1- (point))))
      (decompose-region (- (point) 2) (point)))
     ((and (>= ch #x1200) (<= ch #x137f))
      (insert "????")
      (compose-region (- (point) 2) (point)))
     (t
      (error "")))))

;;;
;;; Robin packages
;;;

(robin-define-package "ethiopic-sera"
 "SERA transliteration system for Ethiopic.
SERA (System for Ethiopic Representation in ASCII) is the Latin
representation of Ethiopic script."

 ("he" ????)
 ("hu" ????)
 ("hi" ????)
 ("ha" ????)
 ("hE" ????) ("hee" "???")
 ("h" ????)
 ("ho" ????)

 ("le" ????) ("Le" "???")
 ("lu" ????) ("Lu" "???")
 ("li" ????) ("Li" "???")
 ("la" ????) ("La" "???")
 ("lE" ????) ("LE" "???") ("lee" "???") ("Lee" "???")
 ("l" ????) ("L" "???")
 ("lo" ????) ("Lo" "???")
 ("lWa" ????) ("LWa" "???") ("lW" "???") ("LW" "???")

 ("He" ????)
 ("Hu" ????)
 ("Hi" ????)
 ("Ha" ????)
 ("HE" ????) ("Hee" "???")
 ("H" ????)
 ("Ho" ????)
 ("HWa" ????) ("HW" "???")

 ("me" ????) ("Me" "???")
 ("mu" ????) ("Mu" "???")
 ("mi" ????) ("Mi" "???")
 ("ma" ????) ("Ma" "???")
 ("mE" ????) ("ME" "???") ("mee" "???") ("Mee" "???")
 ("m" ????) ("M" "???")
 ("mo" ????) ("Mo" "???")
 ("mWa" ????) ("MWa" "???") ("mW" "???") ("MW" "???")

 ("`se" ????) ("sse" "???") ("s2e" "???")
 ("`su" ????) ("ssu" "???") ("s2u" "???")
 ("`si" ????) ("ssi" "???") ("s2i" "???")
 ("`sa" ????) ("ssa" "???") ("s2a" "???")
 ("`sE" ????) ("ssE" "???") ("s2E" "???")
   ("`see" "???") ("ssee" "???") ("s2ee" "???")
 ("`s" ????) ("ss" "???") ("s2" "???")
 ("`so" ????) ("sso" "???") ("s2o" "???")
 ("`sWa" ????) ("ssWa" "???") ("s2Wa" "???")
   ("`sW" "???") ("ssW" "???") ("s2W" "???")

 ("re" ????) ("Re" "???")
 ("ru" ????) ("Ru" "???")
 ("ri" ????) ("Ri" "???")
 ("ra" ????) ("Ra" "???")
 ("rE" ????) ("RE" "???") ("ree" "???") ("Ree" "???")
 ("r" ????) ("R" "???")
 ("ro" ????) ("Ro" "???")
 ("rWa" ????) ("RWa" "???") ("rW" "???") ("RW" "???")

 ("se" ????)
 ("su" ????)
 ("si" ????)
 ("sa" ????)
 ("sE" ????) ("see" "???")
 ("s" ????)
 ("so" ????)
 ("sWa" ????) ("sW" "???")

 ("xe" ????)
 ("xu" ????)
 ("xi" ????)
 ("xa" ????)
 ("xE" ????) ("xee" "???")
 ("x" ????)
 ("xo" ????)
 ("xWa" ????) ("xW" "???")

 ("qe" ????)
 ("qu" ????)
 ("qi" ????)
 ("qa" ????)
 ("qE" ????) ("qee" "???")
 ("q" ????)
 ("qo" ????)
 ("qWe" ????)
 ("qWi" ????)
 ("qWa" ????) ("qW" "???")
 ("qWE" ????) ("qWee" "???")
 ("qW'" ????) ("qWu" "???")

 ("Qe" ????)
 ("Qu" ????)
 ("Qi" ????)
 ("Qa" ????)
 ("QE" ????) ("Qee" "???")
 ("Q" ????)
 ("Qo" ????)
 ("QWe" ????)
 ("QWi" ????)
 ("QWa" ????) ("QW" "???")
 ("QWE" ????) ("QWee" "???")
 ("QW'" ????) ("QWu" "???")

 ("be" ????) ("Be" "???")
 ("bu" ????) ("Bu" "???")
 ("bi" ????) ("Bi" "???")
 ("ba" ????) ("Ba" "???")
 ("bE" ????) ("BE" "???") ("bee" "???") ("Bee" "???")
 ("b" ????) ("B" "???")
 ("bo" ????) ("Bo" "???")
 ("bWa" ????) ("BWa" "???") ("bW" "???") ("BW" "???")

 ("ve" ????) ("Ve" "???")
 ("vu" ????) ("Vu" "???")
 ("vi" ????) ("Vi" "???")
 ("va" ????) ("Va" "???")
 ("vE" ????) ("VE" "???") ("vee" "???") ("Vee" "???")
 ("v" ????) ("V" "???")
 ("vo" ????) ("Vo" "???")
 ("vWa" ????) ("VWa" "???") ("vW" "???") ("VW" "???")

 ("te" ????)
 ("tu" ????)
 ("ti" ????)
 ("ta" ????)
 ("tE" ????) ("tee" "???")
 ("t" ????)
 ("to" ????)
 ("tWa" ????) ("tW" "???")

 ("ce" ????)
 ("cu" ????)
 ("ci" ????)
 ("ca" ????)
 ("cE" ????) ("cee" "???")
 ("c" ????)
 ("co" ????)
 ("cWa" ????) ("cW" "???")

 ("`he" ????) ("hhe" "???") ("h2e" "???")
 ("`hu" ????) ("hhu" "???") ("h2u" "???")
 ("`hi" ????) ("hhi" "???") ("h2i" "???")
 ("`ha" ????) ("hha" "???") ("h2a" "???")
 ("`hE" ????) ("hhE" "???") ("h2E" "???")
   ("`hee" "???") ("hhee" "???") ("h2ee" "???")
 ("`h" ????) ("hh" "???") ("h2" "???")
 ("`ho" ????) ("hho" "???") ("h2o" "???")
 ("`hWe" ????) ("hhWe" "???") ("h2We" "???") ("hWe" "???")
 ("`hWi" ????) ("hhWi" "???") ("h2Wi" "???") ("hWi" "???")
 ("`hWa" ????) ("hhWa" "???") ("h2Wa" "???") ("hWa" "???")
   ("`hW" "???") ("hhW" "???") ("h2W" "???")
 ("`hWE" ????) ("hhWE" "???") ("h2WE" "???") ("hWE" "???")
   ("`hWee" "???") ("hhWee" "???") ("h2Wee" "???") ("hWee" "???")
 ("`hW'" ????) ("hhW'" "???") ("h2W'" "???") ("hW'" "???")
   ("`hWu" "???") ("hhWu" "???") ("h2Wu" "???") ("hWu" "???")

 ("ne" ????)
 ("nu" ????)
 ("ni" ????)
 ("na" ????)
 ("nE" ????) ("nee" "???")
 ("n" ????)
 ("no" ????)
 ("nWa" ????) ("nW" "???")

 ("Ne" ????)
 ("Nu" ????)
 ("Ni" ????)
 ("Na" ????)
 ("NE" ????) ("Nee" "???")
 ("N" ????)
 ("No" ????)
 ("NWa" ????) ("NW" "???")

 ("'A" ????) ("A" "???")
 ("'u" ????) ("u" "???") ("'U" "???") ("U" "???")
 ("'i" ????) ("i" "???")
 ("'a" ????) ("a" "???")
 ("'E" ????) ("E" "???")
 ("'I" ????) ("I" "???") ("'e" "???") ("e" "???")
 ("'o" ????) ("o" "???") ("'O" "???") ("O" "???")
 ("'ea" ????) ("ea" "???")

 ("ke" ????)
 ("ku" ????)
 ("ki" ????)
 ("ka" ????)
 ("kE" ????) ("kee" "???")
 ("k" ????)
 ("ko" ????)
 ("kWe" ????)
 ("kWi" ????)
 ("kWa" ????) ("kW" "???")
 ("kWE" ????) ("kWee" "???")
 ("kW'" ????) ("kWu" "???")

 ("Ke" ????)
 ("Ku" ????)
 ("Ki" ????)
 ("Ka" ????)
 ("KE" ????) ("Kee" "???")
 ("K" ????)
 ("Ko" ????)
 ("KWe" ????)
 ("KWi" ????)
 ("KWa" ????) ("KW" "???")
 ("KWE" ????) ("KWee" "???")
 ("KW'" ????) ("KWu" "???")

 ("we" ????)
 ("wu" ????)
 ("wi" ????)
 ("wa" ????)
 ("wE" ????) ("wee" "???")
 ("w" ????)
 ("wo" ????)

 ("`e" ????) ("ae" "???") ("aaa" "???") ("e2" "???")
 ("`u" ????) ("uu" "???") ("u2" "???") ("`U" "???") ("UU" "???") ("U2" "???")
 ("`i" ????) ("ii" "???") ("i2" "???")
 ("`a" ????) ("aa" "???") ("a2" "???") ("`A" "???") ("AA" "???") ("A2" "???")
 ("`E" ????) ("EE" "???") ("E2" "???")
 ("`I" ????) ("II" "???") ("I2" "???") ("ee" "???")
 ("`o" ????) ("oo" "???") ("o2" "???") ("`O" "???") ("OO" "???") ("O2" "???")

 ("ze" ????)
 ("zu" ????)
 ("zi" ????)
 ("za" ????)
 ("zE" ????) ("zee" "???")
 ("z" ????)
 ("zo" ????)
 ("zWa" ????) ("zW" "???")

 ("Ze" ????)
 ("Zu" ????)
 ("Zi" ????)
 ("Za" ????)
 ("ZE" ????) ("Zee" "???")
 ("Z" ????)
 ("Zo" ????)
 ("ZWa" ????) ("ZW" "???")

 ("ye" ????) ("Ye" "???")
 ("yu" ????) ("Yu" "???")
 ("yi" ????) ("Yi" "???")
 ("ya" ????) ("Ya" "???")
 ("yE" ????) ("YE" "???") ("yee" "???") ("Yee" "???")
 ("y" ????) ("Y" "???")
 ("yo" ????) ("Yo" "???")

 ("de" ????)
 ("du" ????)
 ("di" ????)
 ("da" ????)
 ("dE" ????) ("dee" "???")
 ("d" ????)
 ("do" ????)
 ("dWa" ????) ("dW" "???")

 ("De" ????)
 ("Du" ????)
 ("Di" ????)
 ("Da" ????)
 ("DE" ????) ("Dee" "???")
 ("D" ????)
 ("Do" ????)
 ("DWa" ????) ("DW" "???")

 ("je" ????) ("Je" "???")
 ("ju" ????) ("Ju" "???")
 ("ji" ????) ("Ji" "???")
 ("ja" ????) ("Ja" "???")
 ("jE" ????) ("JE" "???") ("jee" "???") ("Jee" "???")
 ("j" ????) ("J" "???")
 ("jo" ????) ("Jo" "???")
 ("jWa" ????) ("jW" "???") ("JWa" "???") ("JW" "???")

 ("ge" ????)
 ("gu" ????)
 ("gi" ????)
 ("ga" ????)
 ("gE" ????) ("gee" "???")
 ("g" ????)
 ("go" ????)
 ("gWe" ????)
 ("gWi" ????)
 ("gWa" ????) ("gW" "???")
 ("gWE" ????) ("gWee" "???")
 ("gW'" ????) ("gWu" "???")

 ("Ge" ????)
 ("Gu" ????)
 ("Gi" ????)
 ("Ga" ????)
 ("GE" ????) ("Gee" "???")
 ("G" ????)
 ("Go" ????)

 ("Te" ????)
 ("Tu" ????)
 ("Ti" ????)
 ("Ta" ????)
 ("TE" ????) ("Tee" "???")
 ("T" ????)
 ("To" ????)
 ("TWa" ????) ("TW" "???")

 ("Ce" ????)
 ("Cu" ????)
 ("Ci" ????)
 ("Ca" ????)
 ("CE" ????) ("Cee" "???")
 ("C" ????)
 ("Co" ????)
 ("CWa" ????) ("CW" "???")

 ("Pe" ????)
 ("Pu" ????)
 ("Pi" ????)
 ("Pa" ????)
 ("PE" ????) ("Pee" "???")
 ("P" ????)
 ("Po" ????)
 ("PWa" ????) ("PW" "???")

 ("Se" ????)
 ("Su" ????)
 ("Si" ????)
 ("Sa" ????)
 ("SE" ????) ("See" "???")
 ("S" ????)
 ("So" ????)
 ("SWa" ????) ("`SWa" "???") ("SSWa" "???") ("S2Wa" "???")
   ("SW" "???") ("`SW" "???") ("SSW" "???") ("S2W" "???")

 ("`Se" ????) ("SSe" "???") ("S2e" "???")
 ("`Su" ????) ("SSu" "???") ("S2u" "???")
 ("`Si" ????) ("SSi" "???") ("S2i" "???")
 ("`Sa" ????) ("SSa" "???") ("S2a" "???")
 ("`SE" ????) ("SSE" "???") ("S2E" "???")
   ("`See" "???") ("SSee" "???") ("S2ee" "???")
 ("`S" ????) ("SS" "???") ("S2" "???")
 ("`So" ????) ("SSo" "???") ("S2o" "???")

 ("fe" ????) ("Fe" "???")
 ("fu" ????) ("Fu" "???")
 ("fi" ????) ("Fi" "???")
 ("fa" ????) ("Fa" "???")
 ("fE" ????) ("FE" "???") ("fee" "???") ("Fee" "???")
 ("f" ????) ("F" "???")
 ("fo" ????) ("Fo" "???")
 ("fWa" ????) ("FWa" "???") ("fW" "???") ("FW" "???")

 ("pe" ????)
 ("pu" ????)
 ("pi" ????)
 ("pa" ????)
 ("pE" ????) ("pee" "???")
 ("p" ????)
 ("po" ????)
 ("pWa" ????) ("pW" "???")

 ("rYa" ????) ("RYa" "???") ("rY" "???") ("RY" "???")
 ("mYa" ????) ("MYa" "???") ("mY" "???") ("MY" "???")
 ("fYa" ????) ("FYa" "???") ("fY" "???") ("FY" "???")

 (" : " ????) (":" "???") ("`:" "???")
 ("::" ????) ("." "???")
 ("," ????)
 (";" ????)
 ("-:" ????)
 (":-" ????)
 ("`?" ????) ("??" "???")
 (":|:" ????) ("**" "???")

 ;; Explicit syllable delimiter
 ("'" "")

 ;; Quick ASCII input
 ("''" "'")
 (":::" ":")
 (".." ".")
 (",," ",")
 (";;" ";")

 ("`1" ????)
 ("`2" ????)
 ("`3" ????)
 ("`4" ????)
 ("`5" ????)
 ("`6" ????)
 ("`7" ????)
 ("`8" ????)
 ("`9" ????)
 ("`10" ????)
 ("`20" ????)
 ("`30" ????)
 ("`40" ????)
 ("`50" ????)
 ("`60" ????)
 ("`70" ????)
 ("`80" ????)
 ("`90" ????)
 ("`100" ????)
 ("`10000" ????)

 ("`200" "??????")
 ("`300" "??????")
 ("`400" "??????")
 ("`500" "??????")
 ("`600" "??????")
 ("`700" "??????")
 ("`800" "??????")
 ("`900" "??????")
 ("`1000" "??????")
 ("`2000" "??????")
 ("`3000" "??????")
 ("`4000" "??????")
 ("`5000" "??????")
 ("`6000" "??????")
 ("`7000" "??????")
 ("`8000" "??????")
 ("`9000" "??????")
 ("`20000" "??????")
 ("`30000" "??????")
 ("`40000" "??????")
 ("`50000" "??????")
 ("`60000" "??????")
 ("`70000" "??????")
 ("`80000" "??????")
 ("`90000" "??????")
 ("`100000" "??????")
 ("`200000" "??????")
 ("`300000" "??????")
 ("`400000" "??????")
 ("`500000" "??????")
 ("`600000" "??????")
 ("`700000" "??????")
 ("`800000" "??????")
 ("`900000" "??????")
 ("`1000000" "??????")
 )

(register-input-method
 "ethiopic-sera" "Ethiopic"
 'robin-use-package "et" "An input method for Ethiopic.")

(robin-define-package "ethiopic-tex"
 "TeX transliteration system for Ethiopic."

 ("\\heG" ????)				; U+1200 ..
 ("\\huG" ????)
 ("\\hiG" ????)
 ("\\haG" ????)
 ("\\hEG" ????)
 ("\\hG" ????)
 ("\\hoG" ????)
 ;; reserved
 ("\\leG" ????)
 ("\\luG" ????)
 ("\\liG" ????)
 ("\\laG" ????)
 ("\\lEG" ????)
 ("\\lG" ????)
 ("\\loG" ????)
 ("\\lWaG" ????)

 ("\\HeG" ????)				; U+1210 ..
 ("\\HuG" ????)
 ("\\HiG" ????)
 ("\\HaG" ????)
 ("\\HEG" ????)
 ("\\HG" ????)
 ("\\HoG" ????)
 ("\\HWaG" ????)
 ("\\meG" ????)
 ("\\muG" ????)
 ("\\miG" ????)
 ("\\maG" ????)
 ("\\mEG" ????)
 ("\\mG" ????)
 ("\\moG" ????)
 ("\\mWaG" ????)

 ("\\sseG" ????)				; U+1220 ..
 ("\\ssuG" ????)
 ("\\ssiG" ????)
 ("\\ssaG" ????)
 ("\\ssEG" ????)
 ("\\ssG" ????)
 ("\\ssoG" ????)
 ("\\ssWaG" ????)
 ("\\reG" ????)
 ("\\ruG" ????)
 ("\\riG" ????)
 ("\\raG" ????)
 ("\\rEG" ????)
 ("\\rG" ????)
 ("\\roG" ????)
 ("\\rWaG" ????)

 ("\\seG" ????)				; U+1230 ..
 ("\\suG" ????)
 ("\\siG" ????)
 ("\\saG" ????)
 ("\\sEG" ????)
 ("\\sG" ????)
 ("\\soG" ????)
 ("\\sWaG" ????)
 ("\\xeG" ????)
 ("\\xuG" ????)
 ("\\xiG" ????)
 ("\\xaG" ????)
 ("\\xEG" ????)
 ("\\xG" ????)
 ("\\xoG" ????)
 ("\\xWaG" ????)

 ("\\qeG" ????)				; U+1240 ..
 ("\\quG" ????)
 ("\\qiG" ????)
 ("\\qaG" ????)
 ("\\qEG" ????)
 ("\\qG" ????)
 ("\\qoG" ????)
 ;; reserved
 ("\\qWeG" ????)
 ;; reserved
 ("\\qWiG" ????)
 ("\\qWaG" ????)
 ("\\qWEG" ????)
 ("\\qWG" ????)
 ;; reserved
 ;; reserved

 ("\\QeG" ????)				; U+1250 ..
 ("\\QuG" ????)
 ("\\QiG" ????)
 ("\\QaG" ????)
 ("\\QEG" ????)
 ("\\QG" ????)
 ("\\QoG" ????)
 ;; reserved
 ("\\QWeG" ????)
 ;; reserved
 ("\\QWiG" ????)
 ("\\QWaG" ????)
 ("\\QWEG" ????)
 ("\\QWG" ????)
 ;; reserved
 ;; reserved

 ("\\beG" ????)				; U+1260 ..
 ("\\buG" ????)
 ("\\biG" ????)
 ("\\baG" ????)
 ("\\bEG" ????)
 ("\\bG" ????)
 ("\\boG" ????)
 ("\\bWaG" ????)
 ("\\veG" ????)
 ("\\vuG" ????)
 ("\\viG" ????)
 ("\\vaG" ????)
 ("\\vEG" ????)
 ("\\vG" ????)
 ("\\voG" ????)
 ("\\vWaG" ????)

 ("\\teG" ????)				; U+1270 ..
 ("\\tuG" ????)
 ("\\tiG" ????)
 ("\\taG" ????)
 ("\\tEG" ????)
 ("\\tG" ????)
 ("\\toG" ????)
 ("\\tWaG" ????)
 ("\\ceG" ????)
 ("\\cuG" ????)
 ("\\ciG" ????)
 ("\\caG" ????)
 ("\\cEG" ????)
 ("\\cG" ????)
 ("\\coG" ????)
 ("\\cWaG" ????)

 ("\\hheG" ????)				; U+1280 ..
 ("\\hhuG" ????)
 ("\\hhiG" ????)
 ("\\hhaG" ????)
 ("\\hhEG" ????)
 ("\\hhG" ????)
 ("\\hhoG" ????)
 ;; reserved
 ("\\hWeG" ????)
 ;; reserved
 ("\\hWiG" ????)
 ("\\hWaG" ????)
 ("\\hWEG" ????)
 ("\\hWG" ????)
 ;; reserved
 ;; reserved

 ("\\neG" ????)				; U+1290 ..
 ("\\nuG" ????)
 ("\\niG" ????)
 ("\\naG" ????)
 ("\\nEG" ????)
 ("\\nG" ????)
 ("\\noG" ????)
 ("\\nWaG" ????)
 ("\\NeG" ????)
 ("\\NuG" ????)
 ("\\NiG" ????)
 ("\\NaG" ????)
 ("\\NEG" ????)
 ("\\NG" ????)
 ("\\NoG" ????)
 ("\\NWaG" ????)

 ("\\eG" ????)				; U+12A0 ..
 ("\\uG" ????)
 ("\\iG" ????)
 ("\\AG" ????)
 ("\\EG" ????)
 ("\\IG" ????)
 ("\\oG" ????)
 ("\\eaG" ????)
 ("\\keG" ????)
 ("\\kuG" ????)
 ("\\kiG" ????)
 ("\\kaG" ????)
 ("\\kEG" ????)
 ("\\kG" ????)
 ("\\koG" ????)
 ;; reserved

 ("\\kWeG" ????)				; U+12B0 ..
 ;; reserved
 ("\\kWiG" ????)
 ("\\kWaG" ????)
 ("\\kWEG" ????)
 ("\\kWG" ????)
 ;; reserved
 ;; reserved
 ("\\KeG" ????)
 ("\\KuG" ????)
 ("\\KiG" ????)
 ("\\KaG" ????)
 ("\\KEG" ????)
 ("\\KG" ????)
 ("\\KoG" ????)
 ;; reserved

 ("\\KWeG" ????)				; U+12C0 ..
 ;; reserved
 ("\\KWiG" ????)
 ("\\KWaG" ????)
 ("\\KWEG" ????)
 ("\\KWG" ????)
 ;; reserved
 ;; reserved
 ("\\weG" ????)
 ("\\wuG" ????)
 ("\\wiG" ????)
 ("\\waG" ????)
 ("\\wEG" ????)
 ("\\wG" ????)
 ("\\woG" ????)
 ;; reserved

 ("\\eeG" ????)				; U+12D0 ..
 ("\\uuG" ????)
 ("\\iiG" ????)
 ("\\aaG" ????)
 ("\\EEG" ????)
 ("\\IIG" ????)
 ("\\ooG" ????)
 ;; reserved
 ("\\zeG" ????)
 ("\\zuG" ????)
 ("\\ziG" ????)
 ("\\zaG" ????)
 ("\\zEG" ????)
 ("\\zG" ????)
 ("\\zoG" ????)
 ("\\zWaG" ????)

 ("\\ZeG" ????)				; U+12E0 ..
 ("\\ZuG" ????)
 ("\\ZiG" ????)
 ("\\ZaG" ????)
 ("\\ZEG" ????)
 ("\\ZG" ????)
 ("\\ZoG" ????)
 ("\\ZWaG" ????)
 ("\\yeG" ????)
 ("\\yuG" ????)
 ("\\yiG" ????)
 ("\\yaG" ????)
 ("\\yEG" ????)
 ("\\yG" ????)
 ("\\yoG" ????)
 ;; reserved

 ("\\deG" ????)				; U+12F0 ..
 ("\\duG" ????)
 ("\\diG" ????)
 ("\\daG" ????)
 ("\\dEG" ????)
 ("\\dG" ????)
 ("\\doG" ????)
 ("\\dWaG" ????)
 ("\\DeG" ????)
 ("\\DuG" ????)
 ("\\DiG" ????)
 ("\\DaG" ????)
 ("\\DEG" ????)
 ("\\DG" ????)
 ("\\DoG" ????)
 ("\\DWaG" ????)

 ("\\jeG" ????)				; U+1300 ..
 ("\\juG" ????)
 ("\\jiG" ????)
 ("\\jaG" ????)
 ("\\jEG" ????)
 ("\\jG" ????)
 ("\\joG" ????)
 ("\\jWaG" ????)
 ("\\geG" ????)
 ("\\guG" ????)
 ("\\giG" ????)
 ("\\gaG" ????)
 ("\\gEG" ????)
 ("\\gG" ????)
 ("\\goG" ????)
 ;; reserved

 ("\\gWeG" ????)				; U+1310 ..
 ;; reserved
 ("\\gWiG" ????)
 ("\\gWaG" ????)
 ("\\gWEG" ????)
 ("\\gWG" ????)
 ;; reserved
 ;; reserved
 ("\\GeG" ????)
 ("\\GuG" ????)
 ("\\GiG" ????)
 ("\\GaG" ????)
 ("\\GEG" ????)
 ("\\GG" ????)
 ("\\GoG" ????)
 ;; reserved

 ("\\TeG" ????)				; U+1320 ..
 ("\\TuG" ????)
 ("\\TiG" ????)
 ("\\TaG" ????)
 ("\\TEG" ????)
 ("\\TG" ????)
 ("\\ToG" ????)
 ("\\TWaG" ????)
 ("\\CeG" ????)
 ("\\CuG" ????)
 ("\\CiG" ????)
 ("\\CaG" ????)
 ("\\CEG" ????)
 ("\\CG" ????)
 ("\\CoG" ????)
 ("\\CWaG" ????)

 ("\\PeG" ????)				; U+1330 ..
 ("\\PuG" ????)
 ("\\PiG" ????)
 ("\\PaG" ????)
 ("\\PEG" ????)
 ("\\PG" ????)
 ("\\PoG" ????)
 ("\\PWaG" ????)
 ("\\SeG" ????)
 ("\\SuG" ????)
 ("\\SiG" ????)
 ("\\SaG" ????)
 ("\\SEG" ????)
 ("\\SG" ????)
 ("\\SoG" ????)
 ("\\SWaG" ????)

 ("\\SSeG" ????)				; U+1340 ..
 ("\\SSuG" ????)
 ("\\SSiG" ????)
 ("\\SSaG" ????)
 ("\\SSEG" ????)
 ("\\SSG" ????)
 ("\\SSoG" ????)
 ;; reserved
 ("\\feG" ????)
 ("\\fuG" ????)
 ("\\fiG" ????)
 ("\\faG" ????)
 ("\\fEG" ????)
 ("\\fG" ????)
 ("\\foG" ????)
 ("\\fWaG" ????)

 ("\\peG" ????)				; U+1350 ..
 ("\\puG" ????)
 ("\\piG" ????)
 ("\\paG" ????)
 ("\\pEG" ????)
 ("\\pG" ????)
 ("\\poG" ????)
 ("\\pWaG" ????)
 ("\\mYaG" ????)
 ("\\rYaG" ????)
 ("\\fYaG" ????)
 ;; reserved
 ;; reserved
 ;; reserved
 ;; reserved
 ;; reserved

 ;; reserved				; U+1360 ..
 ("\\spaceG" ????)
 ("\\periodG" ????)
 ("\\commaG" ????)
 ("\\semicolonG" ????)
 ("\\colonG" ????)
 ("\\precolonG" ????)
 ("\\oldqmarkG" ????)
 ("\\pbreakG" ????)
 ("\\andG" ????)
 ("\\huletG" ????)
 ("\\sostG" ????)
 ("\\aratG" ????)
 ("\\amstG" ????)
 ("\\sadstG" ????)
 ("\\sabatG" ????)

 ("\\smntG" ????)			; U+1370 ..
 ("\\zeteNG" ????)
 ("\\asrG" ????)
 ("\\heyaG" ????)
 ("\\selasaG" ????)
 ("\\arbaG" ????)
 ("\\hemsaG" ????)
 ("\\slsaG" ????)
 ("\\sebaG" ????)
 ("\\semanyaG" ????)
 ("\\zeTanaG" ????)
 ("\\metoG" ????)
 ("\\asrxiG" ????)
 ;; reserved
 ;; reserved
 ;; reserved

 ;;
 ;; private extension
 ;;

 ("\\yWaG" ?????)				; U+1A00EF (was U+12EF)

 ("\\GWaG" ?????)				; U+1A011F (was U+131F)

 ("\\qqeG" ?????)				; U+1A0180 .. (was U+1380 ..)
 ("\\qquG" ?????)
 ("\\qqiG" ?????)
 ("\\qqaG" ?????)
 ("\\qqEG" ?????)
 ("\\qqG" ?????)
 ("\\qqoG" ?????)
 ;; unused
 ("\\MWeG" ?????)
 ("\\bWeG" ?????)
 ("\\GWeG" ?????)
 ("\\fWeG" ?????)
 ("\\pWeG" ?????)
 ;; unused
 ;; unused
 ;; unused

 ("\\kkeG" ?????)				; U+1A0190 .. (was U+1390 ..)
 ("\\kkuG" ?????)
 ("\\kkiG" ?????)
 ("\\kkaG" ?????)
 ("\\kkEG" ?????)
 ("\\kkG" ?????)
 ("\\kkoG" ?????)
 ;; unused
 ("\\mWiG" ?????)
 ("\\bWiG" ?????)
 ("\\GWiG" ?????)
 ("\\fWiG" ?????)
 ("\\pWiG" ?????)
 ;; unused
 ;; unused
 ;; unused

 ("\\XeG" ?????)				; U+1A01A0 .. (was U+13A0 ..)
 ("\\XuG" ?????)
 ("\\XiG" ?????)
 ("\\XaG" ?????)
 ("\\XEG" ?????)
 ("\\XG" ?????)
 ("\\XoG" ?????)
 ;; unused
 ("\\mWEG" ?????)
 ("\\bWEG" ?????)
 ("\\GWEG" ?????)
 ("\\fWEG" ?????)
 ("\\pWEG" ?????)
 ;; unused
 ;; unused
 ;; unused

 ("\\ggeG" ?????)				; U+1A01B0 .. (was U+13B0 ..)
 ("\\gguG" ?????)
 ("\\ggiG" ?????)
 ("\\ggaG" ?????)
 ("\\ggEG" ?????)
 ("\\ggG" ?????)
 ("\\ggoG" ?????)
 ;; unused
 ("\\mWG" ?????)
 ("\\bWG" ?????)
 ("\\GWG" ?????)
 ("\\fWG" ?????)
 ("\\pWG" ?????)
 ;; unused
 ;; unused
 ;; unused

 ("\\ornamentG" ?????)			; U+1A01C0 .. (was U+FDF0 ..)
 ("\\flandG" ?????)
 ("\\iflandG" ?????)
 ("\\africaG" ?????)
 ("\\iafricaG" ?????)
 ("\\wWeG" ?????)
 ("\\wWiG" ?????)
 ("\\wWaG" ?????)
 ("\\wWEG" ?????)
 ("\\wWG" ?????)
 ;; Gemination (????) is handled in a special way.
 ("\\slaqG" ?????)

 ;; Assign reverse conversion to Fidel chars.
 ;; Then override forward conversion with ASCII chars.
 ;; ASCII chars should not have reverse conversions.
 ("\\dotG" ?????) ("\\dotG" ".")
 ("\\lquoteG" ?????) ("\\lquoteG" "??")
 ("\\rquoteG" ?????) ("\\rquoteG" "??")
 ("\\qmarkG" ?????) ("\\qmarkG" "?")

 ;;
 ;; New characters in Unicode 4.1.
 ;;
 ;; In forward conversion, these characters override the old private
 ;; extensions above.  The old private extensions still keep their
 ;; reverse conversion.
 ;;

 ("\\ornamentG" ????)
 ("\\yWaG" ????)
 ("\\GWaG" ????)
 ("\\MWeG" ????)
 ("\\mWiG" ????)
 ("\\mWEG" ????)
 ("\\mWG" ????)
 ("\\bWeG" ????)
 ("\\bWiG" ????)
 ("\\bWEG" ????)
 ("\\bWG" ????)
 ("\\fWeG" ????)
 ("\\fWiG" ????)
 ("\\fWEG" ????)
 ("\\fWG" ????)
 ("\\pWeG" ????)
 ("\\pWiG" ????)
 ("\\pWEG" ????)
 ("\\pWG" ????)
 ("\\GWeG" ????)
 ("\\GWiG" ????)
 ("\\GWEG" ????)
 ("\\GWG" ????)
 ("\\qqeG" ????)
 ("\\qquG" ????)
 ("\\qqiG" ????)
 ("\\qqaG" ????)
 ("\\qqEG" ????)
 ("\\qqG" ????)
 ("\\qqoG" ????)
 ("\\kkeG" ????)
 ("\\kkuG" ????)
 ("\\kkiG" ????)
 ("\\kkaG" ????)
 ("\\kkEG" ????)
 ("\\kkG" ????)
 ("\\kkoG" ????)
 ("\\XeG" ????)
 ("\\XuG" ????)
 ("\\XiG" ????)
 ("\\XaG" ????)
 ("\\XEG" ????)
 ("\\XG" ????)
 ("\\XoG" ????)
 ("\\ggeG" ????)
 ("\\gguG" ????)
 ("\\ggiG" ????)
 ("\\ggaG" ????)
 ("\\ggEG" ????)
 ("\\ggG" ????)
 ("\\ggoG" ????)
 )

;; The ethiopic-tex package is not used for keyboard input, therefore
;; not registered with the register-input-method function.

;; Local Variables:
;; checkdoc-symbol-words: ("-->")
;; End:

(provide 'ethio-util)

;;; ethio-util.el ends here
