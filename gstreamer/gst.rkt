#lang racket/base

(require (rename-in ffi/unsafe [-> ->>])
         ffi/unsafe/define
         ffi/unsafe/introspection
         racket/class
         racket/contract
         (only-in racket/function
                  curry curryr))

(provide (contract-out [gst
                        gi-repository?]
                       [gst-object%
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
                        (-> boolean?)]
                       [mini-object?
                        (-> any/c
                            boolean?)]
                       [gst-mini-object
                        gi-struct?]
                       [_mini-object
                        ctype?]
                       [mini-object-ref!
                        (-> mini-object? mini-object?)]
                       [mini-object-unref!
                        (-> mini-object? void?)]))

(define gst (introspection 'Gst))

(define libgstreamer (gi-repository->ffi-lib gst))

(define-ffi-definer define-gst libgstreamer)

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

(define gst-mini-object
  (gst 'MiniObject))

(define (mini-object? v)
  (is-gtype? v gst-mini-object))

(define _mini-object
  (_gi-struct gst-mini-object))

(define-gst mini-object-ref! (_fun _mini-object ->> _mini-object)
  #:c-id gst_mini_object_ref)

(define-gst mini-object-unref! (_fun _mini-object ->> _void)
  #:c-id gst_mini_object_unref)
