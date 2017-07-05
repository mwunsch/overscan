#lang racket/base

(require ffi/unsafe/introspection)

(provide gst
         element-factory%)

(define gst (introspection 'Gst))

(define element-factory% (gst 'ElementFactory))
