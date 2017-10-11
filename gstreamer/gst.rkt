#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract)

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
                       [gst-version
                        (-> string?)]))

(define gst (introspection 'Gst))

(define gst-object-mixin
  (make-gobject-delegate get-name
                         get-parent
                         [has-as-parent? 'has_as_parent]
                         get-path-string))

(define gst-object%
  (class (gst-object-mixin gobject%)
    (super-new)
    (inherit-field pointer)))

(define gst-version
  (gst 'version_string))
