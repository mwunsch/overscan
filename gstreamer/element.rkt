#lang racket/base

(require ffi/unsafe/introspection
         "gst.rkt")

(provide element%
         element-factory%)

(define element-factory% (gst 'ElementFactory))

(define element% (gst 'Element))
