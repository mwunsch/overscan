#lang racket/base

(require (rename-in ffi/unsafe [-> ->>])
         ffi/unsafe/define
         ffi/unsafe/introspection
         racket/class
         racket/contract
         (only-in racket/function
                  curry curryr)
         "private/core.rkt")

(provide gst
         (contract-out [gst-object%
                        (class/c
                         [get-name
                          (->m string?)]
                         [get-parent
                          (->m (or/c gobject? #f))]
                         [has-as-parent?
                          (->m gobject? boolean?)]
                         [get-path-string
                          (->m string?)])]
                       [gst-version-string
                        (-> string?)]
                       [gst-version
                        (-> (values exact-integer?
                                    exact-integer?
                                    exact-integer?
                                    exact-integer?))]
                       [gst-initialized?
                        (-> boolean?)]
                       [gst-initialize
                        (-> boolean?)]))

(define gst-object-mixin
  (make-gobject-delegate get-name
                         get-parent
                         [has-as-parent? 'has_as_parent]
                         get-path-string))

(define gst-object%
  (class (gst-object-mixin gobject%)
    (super-new)
    (inherit-field pointer)))

(define gst-version-string
  (gst 'version_string))

(define (gst-version)
  (call-with-values (gst 'version)
                    (compose1 (curry apply values)
                              (curryr list-tail 1)
                              list)))

(define gst-initialized?
  (gst 'is_initialized))

(define (gst-initialize)
  (define-values (initialized? argc argv)
    ((gst 'init_check) 0 #f))
  initialized?)
