;;; viet-util.el --- utilities for Vietnamese  -*- lexical-binding: t; -*-

;; Copyright (C) 1998, 2001-2023 Free Software Foundation, Inc.
;; Copyright (C) 1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004,
;;   2005, 2006, 2007, 2008, 2009, 2010, 2011
;;   National Institute of Advanced Industrial Science and Technology (AIST)
;;   Registration Number H14PRO021
;; Copyright (C) 2003
;;   National Institute of Advanced Industrial Science and Technology (AIST)
;;   Registration Number H13PRO009

;; Keywords: mule, multilingual, Vietnamese

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

;; Vietnamese uses ASCII characters and additional 134 unique
;; characters (these are Latin alphabets with various diacritical and
;; tone marks).  As far as I know, Vietnamese now has 5 different ways
;; for representing these characters: VISCII, TCVN-5712, VPS, VIQR,
;; and Unicode.  VISCII, TCVN-5712 and VPS are simple 1-byte code
;; which assigns 134 unique characters in control-code area
;; (0x00..0x1F) and right half area (0x80..0xFF).  VIQR is a mnemonic
;; encoding specification representing diacritical marks by following
;; ASCII characters.

;;; Code:

(defvar viet-viscii-nonascii-translation-table)

;;;###autoload
(defun viet-encode-viscii-char (char)
  "Return VISCII character code of CHAR if appropriate."
  (encode-char char 'viscii))

;; VIQR is a mnemonic encoding specification for Vietnamese.
;; It represents diacritical marks by ASCII characters as follows:
;; ------------+----------+--------
;;     mark    | mnemonic | example
;; ------------+----------+---------
;;    breve    |    (     | a( -> ??
;;  circumflex |    ^     | a^ -> ??
;;    horn     |    +     | o+ -> ??
;; ------------+----------+---------
;;    acute    |    '     | a' -> ??
;;    grave    |    `     | a` -> ??
;;  hook above |    ?     | a? -> ???
;;    tilde    |    ~     | a~ -> ??
;;   dot below |    .     | a. -> ???
;; ------------+----------+---------
;;    d bar    |   dd     | dd -> ??
;; ------------+----------+---------

(defvar viet-viqr-alist
  '(;; lowercase
    (???? . "a('")			; 161
    (???? . "a(`")			; 162
    (???? . "a(.")			; 163
    (???? . "a^'")			; 164
    (???? . "a^`")			; 165
    (???? . "a^?")			; 166
    (???? . "a^.")			; 167
    (???? . "e~")				; 168
    (???? . "e.")				; 169
    (???? . "e^'")			; 170
    (???? . "e^`")			; 171
    (???? . "e^?")			; 172
    (???? . "e^~")			; 173
    (???? . "e^.")			; 174
    (???? . "o^'")			; 175
    (???? . "o^`")			; 176
    (???? . "o^?")			; 177
    (???? . "o^~")			; 178
    (???? . "o^.")			; 181
    (???? . "o+`")			; 182
    (???? . "o+?")			; 183
    (???? . "i.")				; 184
    (??? . "o+")				; 189
    (???? . "o+'")			; 190
    (???? . "a(?")			; 198
    (???? . "a(~")			; 199
    (???? . "y`")				; 207
    (???? . "u+'")			; 209
    (???? . "a.")				; 213
    (???? . "y?")				; 214
    (???? . "u+`")			; 215
    (???? . "u+?")			; 216
    (???? . "y~")				; 219
    (???? . "y.")				; 220
    (???? . "o+~")			; 222
    (??? . "u+")				; 223
    (??? . "a`")				; 224
    (??? . "a'")				; 225
    (??? . "a^")				; 226
    (??? . "a~")				; 227
    (???? . "a?")				; 228
    (??? . "a(")				; 229
    (???? . "u+~")			; 230
    (???? . "a^~")			; 231
    (??? . "e`")				; 232
    (??? . "e'")				; 233
    (??? . "e^")				; 234
    (???? . "e?")				; 235
    (??? . "i`")				; 236
    (??? . "i'")				; 237
    (??? . "i~")				; 238
    (???? . "i?")				; 239
    (??? . "dd")				; 240
    (???? . "u+.")			; 241
    (??? . "o`")				; 242
    (??? . "o'")				; 243
    (??? . "o^")				; 244
    (??? . "o~")				; 245
    (???? . "o?")				; 246
    (???? . "o.")				; 247
    (???? . "u.")				; 248
    (??? . "u`")				; 249
    (??? . "u'")				; 250
    (??? . "u~")				; 251
    (???? . "u?")				; 252
    (??? . "y'")				; 253
    (???? . "o+.")			; 254

    ;; upper case
    (???? . "A('")			; 161
    (???? . "A(`")			; 162
    (???? . "A(.")			; 163
    (???? . "A^'")			; 164
    (???? . "A^`")			; 165
    (???? . "A^?")			; 166
    (???? . "A^.")			; 167
    (???? . "E~")				; 168
    (???? . "E.")				; 169
    (???? . "E^'")			; 170
    (???? . "E^`")			; 171
    (???? . "E^?")			; 172
    (???? . "E^~")			; 173
    (???? . "E^.")			; 174
    (???? . "O^'")			; 175
    (???? . "O^`")			; 176
    (???? . "O^?")			; 177
    (???? . "O^~")			; 178
    (???? . "O^.")			; 181
    (???? . "O+`")			; 182
    (???? . "O+?")			; 183
    (???? . "I.")				; 184
    (??? . "O+")				; 189
    (???? . "O+'")			; 190
    (???? . "A(?")			; 198
    (???? . "A(~")			; 199
    (???? . "Y`")				; 207
    (???? . "U+'")			; 209
    (???? . "A.")				; 213
    (???? . "Y?")				; 214
    (???? . "U+`")			; 215
    (???? . "U+?")			; 216
    (???? . "Y~")				; 219
    (???? . "Y.")				; 220
    (???? . "O+~")			; 222
    (??? . "U+")				; 223
    (??? . "A`")				; 224
    (??? . "A'")				; 225
    (??? . "A^")				; 226
    (??? . "A~")				; 227
    (???? . "A?")				; 228
    (??? . "A(")				; 229
    (???? . "U+~")			; 230
    (???? . "A^~")			; 231
    (??? . "E`")				; 232
    (??? . "E'")				; 233
    (??? . "E^")				; 234
    (???? . "E?")				; 235
    (??? . "I`")				; 236
    (??? . "I'")				; 237
    (??? . "I~")				; 238
    (???? . "I?")				; 239
    (??? . "DD")				; 240
    (??? . "dD")				; 240
    (??? . "Dd")				; 240
    (???? . "U+.")			; 241
    (??? . "O`")				; 242
    (??? . "O'")				; 243
    (??? . "O^")				; 244
    (??? . "O~")				; 245
    (???? . "O?")				; 246
    (???? . "O.")				; 247
    (???? . "U.")				; 248
    (??? . "U`")				; 249
    (??? . "U'")				; 250
    (??? . "U~")				; 251
    (???? . "U?")				; 252
    (??? . "Y'")				; 253
    (???? . "O+.")			; 254

    ;; escape from composition
    (?\( . "\\(")			; breve (left parenthesis)
    (?^ . "\\^")			; circumflex (caret)
    (?+ . "\\+")			; horn (plus sign)
    (?' . "\\'")			; acute (apostrophe)
    (?` . "\\`")			; grave (backquote)
    (?? . "\\?")			; hook above (question mark)
    (?~ . "\\~")			; tilde (tilde)
    (?. . "\\.")			; dot below (period)
    (?d . "\\d")			; d-bar (d)
    (?\\ . "\\\\")			; literal backslash
    )
  "Alist of Vietnamese characters vs corresponding `VIQR' string.")

;; Regular expression matching single Vietnamese character represented
;; by VIQR.
(defconst viqr-regexp
  "[aeiouyAEIOUY]\\([(^+]?['`?~.]\\|[(^+]\\)\\|[Dd][Dd]")

;;;###autoload
(defun viet-decode-viqr-region (from to)
  "Convert `VIQR' mnemonics of the current region to Vietnamese characters.
When called from a program, expects two arguments,
positions (integers or markers) specifying the stretch of the region."
  (interactive "r")
  (save-restriction
    (narrow-to-region from to)
    (goto-char (point-min))
    (while (re-search-forward viqr-regexp nil t)
      (let* ((viqr (buffer-substring (match-beginning 0) (match-end 0)))
	     (ch (car (rassoc viqr viet-viqr-alist))))
	(if ch
	    (progn
	      (delete-region (match-beginning 0) (match-end 0))
	      (insert ch)))))))

;;;###autoload
(defun viet-decode-viqr-buffer ()
  "Convert `VIQR' mnemonics of the current buffer to Vietnamese characters."
  (interactive)
  (viet-decode-viqr-region (point-min) (point-max)))

;;;###autoload
(defun viet-encode-viqr-region (from to)
  "Convert Vietnamese characters of the current region to `VIQR' mnemonics.
When called from a program, expects two arguments,
positions (integers or markers) specifying the stretch of the region."
  (interactive "r")
  (save-restriction
    (narrow-to-region from to)
    (goto-char (point-min))
    (while (re-search-forward "\\cv" nil t)
      (let* ((ch (preceding-char))
	     (viqr (cdr (assq ch viet-viqr-alist))))
	(if viqr
	    (progn
	      (delete-char -1)
	      (insert viqr)))))))

;;;###autoload
(defun viet-encode-viqr-buffer ()
  "Convert Vietnamese characters of the current buffer to `VIQR' mnemonics."
  (interactive)
  (viet-encode-viqr-region (point-min) (point-max)))

;;;###autoload
(defun viqr-post-read-conversion (len)
  (save-excursion
    (save-restriction
      (narrow-to-region (point) (+ (point) len))
      (let ((buffer-modified-p (buffer-modified-p)))
	(viet-decode-viqr-region (point-min) (point-max))
	(set-buffer-modified-p buffer-modified-p)
	(- (point-max) (point-min))))))

;;;###autoload
(defun viqr-pre-write-conversion (from to)
  (let ((old-buf (current-buffer)))
    (set-buffer (generate-new-buffer " *temp*"))
    (if (stringp from)
	(insert from)
      (insert-buffer-substring old-buf from to))
    (viet-encode-viqr-region (point-min) (point-max))
    ;; Should return nil as annotations.
    nil))

;;;
(provide 'viet-util)

;;; viet-util.el ends here
