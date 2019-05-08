;;; leaf.el --- Symplify your init.el configuration       -*- lexical-binding: t; -*-

;; Copyright (C) 2018  Naoya Yamashita

;; Author: Naoya Yamashita <conao3@gmail.com>
;; Maintainer: Naoya Yamashita <conao3@gmail.com>
;; Keywords: lisp settings
;; Version: 2.1.9
;; URL: https://github.com/conao3/leaf.el
;; Package-Requires: ((emacs "24.0"))

;;   Abobe declared this package requires Emacs-24, but it's for warning
;;   suppression, and will actually work from Emacs-22.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; simpify init.el

;;; Code:

(require 'leaf-polyfill)

(defgroup leaf nil
  "Symplifying your `.emacs' configuration."
  :group 'lisp)

(defcustom leaf-defaults '()
  "Default values for each leaf packages."
  :type 'sexp
  :group 'leaf)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Customize backend
;;

(defcustom leaf-backend-ensure (if (require 'feather nil t) 'feather
                                  (if (require 'package nil t) 'package))
  "Backend to process `:ensure' keyword."
  :type '(choice (const :tag "Use `package.el'." 'package)
                 (const :tag "Use `feather.el'." 'feather)
                 (const :tag "No backend, disable `:ensure'." nil))
  :group 'leaf)

(defcustom leaf-backend-bind (if (require 'bind-key nil t) 'bind-key)
  "Backend to process `:bind' keyword."
  :type '(choice (const :tag "Use `bind-key.el'." 'bind-key)
                 (const :tag "No backend, disable `:bind'." nil))
  :group 'leaf)

(defcustom leaf-backend-bind* (if (require 'bind-key nil t) 'bind-key)
  "Backend to process `:bind*' keyword."
  :type '(choice (const :tag "Use `bind-key.el'." 'bind-key)
                 (const :tag "No backend, disable `:bind'." nil))
  :group 'leaf)

(defcustom leaf-options-ensure-default-pin nil
  "Option :ensure pin default.
'nil is using package manager default."
  :type 'sexp
  :group 'leaf)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  leaf keywords definition
;;

(defvar leaf-keywords
  '(:dummy
    :disabled (unless (eval (car value)) `(,@body))
    :ensure `(,@(mapcar
                 (lambda (elm)
                   (let ((pkg `',(car elm))
                         (pin (cdr elm)))
                     (cond
                      ((eq leaf-backend-ensure 'package)
                       `(unless (package-installed-p ,pkg)
                          (condition-case-unless-debug err
                              (if (assoc ,pkg package-archive-contents)
                                  (package-install ,pkg)
                                (package-refresh-contents)
                                (package-install ,pkg))
                            (error
                             (display-warning 'leaf
                                              (format "Failed to install %s: %s"
                                                      ,pkg (error-message-string err))
                                              :error))))))))
                 value)
              ,@body)
    :doc `(,@body) :file `(,@body) :url `(,@body)

    :load-path `(,@(mapcar (lambda (elm) `(add-to-list 'load-path ,elm)) value) ,@body)
    :defun `(,@(mapcar (lambda (elm) `(declare-function ,(car elm) ,(symbol-name (cdr elm)))) value) ,@body)
    :defvar `(,@(mapcar (lambda (elm) `(defvar ,elm)) value) ,@body)
    :preface `(,@value ,@body)

    :when (when body
            `((when ,@(if (= 1 (length value)) value `((and ,@value)))
                ,@body)))
    :unless (when body
              `((unless ,@(if (= 1 (length value)) value `((and ,@value)))
                  ,@body)))
    :if (when body
          `((if ,@(if (= 1 (length value)) value `((and ,@value)))
                (progn ,@body))))

    :after (when body
             (let ((ret `(progn ,@body)))
               (dolist (elm value) (setq ret `(eval-after-load ',elm ',ret)))
               `(,ret)))

    :custom `((custom-set-variables ,@(mapcar (lambda (elm) `'(,(car elm) ,(cdr elm) ,(format "Customized with leaf in %s block" name))) value)) ,@body)
    :custom-face `((custom-set-faces ,@(mapcar (lambda (elm) `'(,(car elm) ,(cddr elm))) value)) ,@body)
    :bind
    (progn
      (mapc (lambda (elm) (leaf-register-autoload (cdar (last elm)) name)) value)
      `(,@(mapcar (lambda (elm) `(bind-keys ,@elm)) value) ,@body))
    :bind*
    (progn
      (mapc (lambda (elm) (leaf-register-autoload (cdar (last elm)) name)) value)
      `(,@(mapcar (lambda (elm) `(bind-keys* ,@elm)) value) ,@body))

    :mode
    (progn
      (mapc (lambda (elm) (leaf-register-autoload (cdr elm) name)) value)
      `(,@(mapcar (lambda (elm) `(add-to-list 'auto-mode-alist '(,(car elm) ,(cdr elm)))) value) ,@body))
    :interpreter
    (progn
      (mapc (lambda (elm) (leaf-register-autoload (cdr elm) name)) value)
      `(,@(mapcar (lambda (elm) `(add-to-list 'interpreter-mode-alist '(,(car elm) ,(cdr elm)))) value) ,@body))
    :magic
    (progn
      (mapc (lambda (elm) (leaf-register-autoload (cdr elm) name)) value)
      `(,@(mapcar (lambda (elm) `(add-to-list 'magic-mode-alist '(,(car elm) ,(cdr elm)))) value) ,@body))
    :magic-fallback
    (progn
      (mapc (lambda (elm) (leaf-register-autoload (cdr elm) name)) value)
      `(,@(mapcar (lambda (elm) `(add-to-list 'magic-fallback-mode-alist '(,(car elm) ,(cdr elm)))) value) ,@body))
    :hook
    (progn
      (mapc (lambda (elm) (leaf-register-autoload (cdr elm) name)) value)
      `(,@(mapcar (lambda (elm) `(add-hook ',(car elm) #',(cdr elm))) value) ,@body))

    :commands (progn (mapc (lambda (elm) (leaf-register-autoload elm name)) value) `(,@body))
    :pre-setq `(,@(mapcar (lambda (elm) `(setq ,(car elm) ,(cdr elm))) value) ,@body)
    :init `(,@value ,@body)
    :require `(,@(mapcar (lambda (elm) `(require ',elm)) value) ,@body)
    :setq `(,@(mapcar (lambda (elm) `(setq ,(car elm) ,(cdr elm))) value) ,@body)
    :setq-default `(,@(mapcar (lambda (elm) `(setq-default ,(car elm) ,(cdr elm))) value) ,@body)
    :config `(,@value ,@body)
    )
  "Special keywords and conversion rule to be processed by `leaf'.
Sort by `leaf-sort-values-plist' in this order.")

(defvar leaf-normarize
  '(((memq key '(:require))
     ;; Accept: 't, 'nil, symbol and list of these (and nested)
     ;; Return: symbol list.
     ;; Note  : 't will convert to 'name
     ;;         if 'nil placed on top, ignore all argument
     ;;         remove duplicate element
     (let ((ret (leaf-flatten value)))
       (if (eq nil (car ret))
           nil
         (delete-dups (delq nil (leaf-subst t name ret))))))
    ((memq key '(:load-path :commands :after :defvar))
     ;; Accept: 't, 'nil, symbol and list of these (and nested)
     ;; Return: symbol list.
     ;; Note  : 'nil is just ignored
     ;;         remove duplicate element
     (delete-dups (delq nil (leaf-flatten value))))
    ((memq key '(:bind :bind*))
     ;; Accept: list of pair (bind . func),
     ;;         ([:{{hoge}}-map] [:package {{pkg}}](bind . func) (bind . func) ...)
     ;;         optional, [:{{hoge}}-map] [:package {{pkg}}]
     ;; Return: list of ([:{{hoge}}-map] [:package {{pkg}}] (bind . func))
     (let ((ret) (fn))
       (setq fn (lambda (elm ret)
                  (cond
                   ((leaf-pairp elm)
                    (if (member elm ret)
                        ret
                      (cons `(:package ,name ,elm) ret)))
                   ((listp elm)
                    (if (not (atom (car elm)))
                        (progn
                          (dolist (el elm)
                            (setq ret (funcall fn el ret)))
                          ret)
                      (let ((map        (make-symbol (substring (symbol-name (car elm)) 1)))
                            (package    (plist-get (cdr elm) :package))
                            (prefix     (plist-get (cdr elm) :prefix))
                            (prefix-map (plist-get (cdr elm) :prefix-map))
                            (menu-name  (plist-get (cdr elm) :menu-name))
                            (filter     (plist-get (cdr elm) :filter)))
                        (dolist (el elm)
                          (let ((target
                                 (cdr `(:dummy
                                        :map ,map
                                        ,@(if package `(:package ,package)
                                            `(:package ,name))
                                        ,@(when prefix `(:prefix ,prefix))
                                        ,@(when prefix-map `(:prefix-map ,prefix-map))
                                        ,@(when menu-name `(:manu-name ,menu-name))
                                        ,@(when filter `(:filter ,filter))
                                        ,el))))
                            (cond
                             ((leaf-pairp el)
                              (if (member target ret)
                                  ret
                                (setq ret (cons target ret))))
                             ((listp el)
                              (setq ret (funcall fn target ret)))))))
                      ret))
                   (t
                    (warn (format "Value %s is malformed." value))))))
       (dolist (elm value)
         (setq ret (funcall fn elm ret)))
       (nreverse ret)))
    ((memq key '(:ensure))
     ;; Accept: pkg, (pkg . pin), ((pkg pkg ...) . pin),
     ;;         (pkg pkg ... . pin) and list of these (and nested)
     ;; Return: list of pair (pkg . pin).
     ;; Note  : t will convert (name . nil)
     ;;         if omit pin, use `leaf-options-ensure-default-pin'.
     ;;         if pin is 'nil, use package manager default
     ;;         remove duplicate configure
     ;;         't and 'nil are just ignored
     (let ((ret) (fn))
       (setq fn (lambda (elm ret)
                  (cond
                   ((eq t elm)
                    (cons `(,name . nil) ret))
                   ((eq nil elm)
                    ret)
                   ((atom elm)
                    (let ((sym `(,elm . ,leaf-options-ensure-default-pin)))
                      (if (member sym ret)
                          ret
                        (cons sym ret))))
                   ((leaf-pairp elm)
                    (if (listp (car elm))
                        (progn
                          (dolist (el (car elm))
                            (setq ret (funcall fn `(,el . ,(cdr elm)) ret)))
                          ret)
                      (if (member elm ret)
                          ret
                        (cons elm ret))))
                   ((leaf-dotlistp elm)
                    (let ((tail (nthcdr (safe-length elm) elm)))
                      (while (not (atom elm))
                        (setq ret (funcall fn `(,(car elm) . ,tail) ret))
                        (pop elm))
                      ret))
                   ((listp elm)
                    (dolist (el elm)
                      (setq ret (funcall fn el ret)))
                    ret)
                   (t
                    (warn (format "Value %s is malformed." value))))))
       (dolist (elm value)
         (setq ret (funcall fn elm ret)))
       (nreverse ret)))
    ((memq key '(:hook :mode :interpreter :magic :magic-fallback :defun))
     ;; Accept: func, (hook . func), ((hook hook ...) . func),
     ;;         (hook hook ... . func) and list of these (and nested)
     ;; Return: list of pair (hook . func).
     ;; Note  : if omit hook, use name as hook
     ;;         remove duplicate configure
     ;;         't and 'nil are just ignored
     (let ((ret) (fn))
       (setq fn (lambda (elm ret)
                  (cond
                   ((eq t elm)
                    ret)
                   ((eq nil elm)
                    ret)
                   ((atom elm)
                    (let ((sym `(,elm . ,name)))
                      (if (member sym ret)
                          ret
                        (cons sym ret))))
                   ((leaf-pairp elm)
                    (if (listp (car elm))
                        (progn
                          (if (leaf-dotlistp (car elm))
                              (setq ret (funcall fn (car elm) ret))
                            (dolist (el (car elm))
                              (setq ret (funcall fn `(,el . ,(cdr elm)) ret))))
                          ret)
                      (if (member elm ret)
                          ret
                        (cons elm ret))))
                   ((leaf-dotlistp elm)
                    (let ((tail (nthcdr (safe-length elm) elm)))
                      (while (not (atom elm))
                        (setq ret (funcall fn `(,(car elm) . ,tail) ret))
                        (pop elm))
                      ret))
                   ((listp elm)
                    (dolist (el elm)
                      (setq ret (funcall fn el ret)))
                    ret)
                   (t
                    (warn (format "Value %s is malformed." value))))))
       (dolist (elm value)
         (setq ret (funcall fn elm ret)))
       (nreverse ret)))
    ((memq key '(:setq :pre-setq :setq-default :custom :custom-face))
     ;; Accept: (sym . val), ((sym sym ...) . val), (sym sym ... . val)
     ;; Return: list of pair (sym . val)
     ;; Note  : atom ('t, 'nil, symbol) is just ignored
     ;;         remove duplicate configure
     (let ((ret) (fn))
       (setq fn (lambda (elm ret)
                  (cond
                   ((atom elm)
                    ret)
                   ((leaf-pairp elm)
                    (if (listp (car elm))
                        (progn
                          (dolist (el (car elm))
                            (setq ret (funcall fn `(,el . ,(cdr elm)) ret)))
                          ret)
                      (if (member elm ret)
                          ret
                        (cons elm ret))))
                   ((leaf-pairp elm)
                    (let ((tail (cdr elm)))
                      (if (listp (car elm))
                          (progn
                            (dolist (el (car elm))
                              (let ((target `(,el . ,tail)))
                                (if (member target ret)
                                    ret
                                  (setq ret (cons target ret)))))
                            ret)
                        (let ((target `(,(car elm) . ,tail)))
                          (if (member target ret)
                              ret
                            (cons target ret))))))
                   ((member `',(nth (- (safe-length elm) 2) elm) '('quote 'function))
                    (let ((tail (nthcdr (- (safe-length elm) 2) elm)))
                      (while (not (= 2 (safe-length elm)))
                        (if (and (listp (car elm))
                                 (or (leaf-dotlistp (car elm))
                                     (member `',(nth (- (safe-length (car elm)) 2) (car elm)) '('quote 'function))))
                            (setq ret (funcall fn (car elm) ret))
                          (if (listp (car elm))
                              (setq ret (funcall fn `(,@(car elm) . ,tail) ret))
                            (let ((target `(,(car elm) . ,tail)))
                              (if (member target ret)
                                  ret
                                (setq ret (cons target ret))))))
                        (pop elm))
                      ret))
                   ((leaf-dotlistp elm)
                    (let ((tail (nthcdr (safe-length elm) elm)))
                      (while (not (atom elm))
                        (setq ret (funcall fn `(,(car elm) . ,tail) ret))
                        (pop elm))
                      ret))
                   ((listp elm)
                    (dolist (el elm)
                      (setq ret (funcall fn el ret)))
                    ret)
                   (t
                    (warn (format "Value %s is malformed." value))))))
       (dolist (elm value)
         (setq ret (funcall fn elm ret)))
       (nreverse ret)))
    ((memq key '(:disabled :if :when :unless :doc :file :url :preface :init :config))
     value)
    (t
     value))
  "Normarize rule")

(defun leaf-process-keywords (name plist)
  "Process keywords for NAME.
NOTE:
Not check PLIST, PLIST has already been carefully checked
parent funcitons.
Don't call this function directory."
  (when plist
    (let* ((key   (pop plist))
           (value (leaf-normarize-args name key (pop plist)))
           (body  (leaf-process-keywords name plist)))
      (eval
       `(let ((name  ',name)
              (key   ',key)
              (value ',value)
              (body  ',body)
              (rest  ',plist))
          ,(plist-get (cdr leaf-keywords) key))))))

(defun leaf-normarize-args (name key value)
  "Normarize for NAME, KEY and VALUE."
  (eval
   `(let ((name  ',name)
          (key   ',key)
          (value ',value))
      (cond
       ,@leaf-normarize))))

(defvar leaf--autoload)
(defun leaf-register-autoload (fn pkg)
  "Registry FN as autoload for PKG."
  (let ((target `(,fn . ,(symbol-name pkg))))
    (when (not (member target leaf--autoload))
      (setq leaf--autoload (cons target leaf--autoload)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Support functions
;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Formatting leaf
;;

;;;###autoload
(defun leaf-to-string (sexp)
  "Return format string of `leaf' SEXP like `pp-to-string'."
  (with-temp-buffer
    (insert (replace-regexp-in-string
             (eval
              `(rx (group
                    (or ,@(mapcar #'symbol-name leaf-keywords)))))
             "\n\\1"
             (prin1-to-string sexp)))
    (delete-trailing-whitespace)
    (emacs-lisp-mode)
    (indent-region (point-min) (point-max))
    (buffer-substring-no-properties (point-min) (point-max))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  General list functions for leaf
;;

(defun leaf-append-defaults (plist)
  "Append leaf default values to PLIST."
  (append plist leaf-defaults))

(defun leaf-add-keyword-before (target belm)
  "Add leaf keyword as name TARGET before BELM."
  (if (memq target leaf-keywords)
      (warn (format "%s already exists in `leaf-keywords'" target))
    (setq leaf-keywords
          (leaf-insert-before leaf-keywords target belm))))

(defun leaf-add-keyword-after (target aelm)
  "Add leaf keyword as name TARGET after AELM."
  (if (memq target leaf-keywords)
      (warn (format "%s already exists in `leaf-keywords'" target))
    (setq leaf-keywords
          (leaf-insert-after leaf-keywords target aelm))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Pseudo-plist functions
;;

;; pseudo-PLIST is list separated value with :keyword.
;;   such as (:key1 v1 v2 :key2 v3 :key3 v4 v5 v6)
;;
;; PLIST is normalized plist, and duplicate keys are allowed.
;;   such as (:key1 (v1 v2) :key2 v3 :key3 (v4 v5 v6)),
;;           (:key1 (v1 v2) :key2 v3 :key2 (v4 v5 v6))
;;
;; well-formed PLIST is normalized plst, and duplicate keys are NOT allowed.
;;   such as (:key1 (v1 v2) :key2 v3 :key3 (v4 v5 v6))
;;
;; list-valued PLIST is well-formed PLIST and value are ALWAYS list.
;; Duplicate keys are NOT allowed.
;;   such as (:key1 (v1 v2) :key2 (v3) :key2 (v4 v5 v6))
;;
;; sorted-list PLIST is list-valued PLIST and keys are sorted by `leaf-keywords'
;; Duplicate keys are NOT allowed.
;;   such as (:if (t) :config ((prin1 "a") (prin1 "b)))

(defun leaf-sort-values-plist (plist)
  "Given a list-valued PLIST, return sorted-list PLIST.

EXAMPLE:
  (leaf-sort-values-plist
    '(:config (message \"a\")
      :disabled (t)))
  => (:disabled (t)
      :config (message \"a\"))"
  (let ((retplist))
    (dolist (key (leaf-plist-keys (cdr leaf-keywords)))
      (if (plist-member plist key)
          (setq retplist `(,@retplist ,key ,(plist-get plist key)))))
    retplist))

(defun leaf-merge-dupkey-values-plist (plist)
  "Given a PLIST, return list-valued PLIST.

EXAMPLE:
  (leaf-merge-value-on-duplicate-key
    '(:defer (t)
      :config ((message \"a\") (message \"b\"))
      :config ((message \"c\"))))
  => (:defer (t)
      :config ((message \"a\") (message \"b\") (message \"c\")))"
  (let ((retplist) (key) (value))
    (while plist
      (setq key (pop plist))
      (setq value (pop plist))

      (if (plist-member retplist key)
          (plist-put retplist key `(,@(plist-get retplist key) ,@value))
        (setq retplist `(,@retplist ,key ,value))))
    retplist))

(defun leaf-normalize-plist (plist &optional mergep evalp)
  "Given a pseudo-PLIST, return PLIST.
If MERGEP is t, return well-formed PLIST.
If EVALP is t, `eval' each element which have `quote' or `backquote'.

EXAMPLE:
  (leaf-normalize-plist
    '(:defer t
      :config (message \"a\") (message \"b\")
      :config (message \"c\")) nil)
  => (:defer (t)
      :config ((message \"a\") (message \"b\"))
      :config ((message \"c\")))

  (leaf-normalize-plist
    '(:defer t
      :config (message \"a\") (message \"b\")
      :config (message \"c\")) t)
  => (:defer (t)
      :config ((message \"a\") (message \"b\") (message \"c\"))"

  ;; using reverse list, push (:keyword worklist) when find :keyword
  (let ((retplist) (worklist) (rlist (reverse plist)))
    (dolist (target rlist)
      (if (keywordp target)
          (progn
            (push worklist retplist)
            (push target retplist)

            ;; clean worklist for new keyword
            (setq worklist nil))
        (push (if (and evalp
                       (listp target)
                       (member `',(car target) `('quote ',backquote-backquote-symbol)))
                  (eval target)
                target)
              worklist)))

    ;; merge value for duplicated key if MERGEP is t
    (if mergep (leaf-merge-dupkey-values-plist retplist) retplist)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Main macro
;;

(defmacro leaf (name &rest args)
  "Symplify your `.emacs' configuration for package NAME with ARGS."
  (declare (indent defun))
  (let* ((leaf--autoload)
         (args* (leaf-sort-values-plist
                 (leaf-normalize-plist
                  (leaf-append-defaults args) 'merge 'eval)))
         (body (leaf-process-keywords name args*)))
    (when (or body leaf--autoload)
      `(progn
         ,@(mapcar
            (lambda (elm) `(autoload #',(car elm) ,(cdr elm) nil t))
            (nreverse leaf--autoload))
         ,@body))))

(provide 'leaf)
;;; leaf.el ends here