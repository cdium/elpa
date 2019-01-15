;;; cpio-newc-tests.el --- Functions to help test cpio-newc.el. -*- coding: utf-8 -*-

;; COPYRIGHT

;; Copyright © 2019 Free Software Foundation, Inc.
;; All rights reserved.
;; 
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;; 
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;; 
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;; 

;; Author: Douglas Lewan <d.lewan2000@gmail.com>
;; Maintainer: Douglas Lewan <d.lewan2000@gmail.com>
;; Created: 2015 Apr 23
;; Version: 0.15β
;; Keywords: files

;;; Commentary:

;;; Documentation:

;; Right now this is just a text file containing things
;; for which test code should be written.
;; It's not even proposing a test harness, just topics.

;; • DONE symbolic mode encoding
;; • symbolic mode decoding
;; • DONE (round-up)
;; • DONE (Full header length) == 0 mod 4.
;; • header construction then parsing yields the original information.
;; • (mapcar 'length (cpio-newc-parse-header-at-point))
;;   => (6 8 8 8 8 8 8 8 8 8 8 8 8 8 n)
;; • (= (length (cpio-newc-header-at-point))
;;     (apply '+ (mapcar 'length (cpio-newc-parse-header-at-point))))
;; • STARTED (cpio-discern-archive-type)

;;; Code:

;;
;; Dependencies
;; 
(eval-when-compile
  (require 'ert))
(unless (featurep 'ert)
  (require 'ert))
(condition-case err
    (require 'cpio-newc)
  (error (if (file-exists-p (concat default-directory "cpio-newc.elc"))
	     (load-file (concat default-directory "cpio-newc.elc"))
	   (if (file-exists-p (concat default-directory "cpio-newc.el"))
	       (load-file (concat default-directory "cpio-newc.el"))))))

;; 
;; Vars
;; 

;; MAINTENANCE: The following list of fields denotes the individual fields in the headers variable.
(defvar *cpio-newc-header-field-names* ()
  "An ordered list of the field names of a newc header.")
(setq *cpio-newc-header-field-names* (list "magic number"
					   "inode"
					   "mode"
					   "uid"
					   "gid"

					   "number of links"
					   "modification time"
					   "filesize"
					   "major device"
					   "minor device"

					   "major rdev"
					   "minoe rdev"
					   "name size"
					   "checksum"
					   "filename"))

;; MAINTENANCE: See the MAINTENANCE note on *cpio-newc-header-field-names*.
(defvar cpio-newc-headers ()
  "A list of ( HEADER . PARSED-HEADER ) pairs.
The HEADER is padded;
you should strip the trailing NULLS before using it.")
(setq cpio-newc-headers (list (cons "070701005A0DDD000081A4000003E8000003E800000001567EA4FC000000D5000000FC0000000100000000000000000000000900000000CALENDAR\0\0"
			  (list "070701"
				"005A0DDD"
				"000081A4"
				"000003E8"
				"000003E8"

				"00000001"
				"567EA4FC"
				"000000D5"
				"000000FC"
				"00000001"

				"00000000"
				"00000000"
				"00000009"
				"00000000"
				"CALENDAR"))))

;; 
;; Library
;; 
(ert-deftest parse-newc-header-1 ()
  "Basic parsing test of the individual fields of a header."
  (mapc (lambda (h-i)
	  (let ((j 0)
		(header-string)
		(fields))
	    (mapc (lambda (f)
		    (should (equal f (aref fields j)))
		    (setq j (1+ j)))
		  fields)))
	cpio-newc-headers))


;; 
;; Commands
;; 


;; 
;; Run tests.
;; 

(unless noninteractive

  (with-current-buffer *cab-info-buffer* (erase-buffer))

  (ert "parse-newc-header-1")

  (pop-to-buffer *cab-info-buffer*))


(provide 'cpio-newc-tests)
;;; cpio-newc-tests.el ends here