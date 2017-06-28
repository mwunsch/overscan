#lang racket/base

(require ffi/unsafe
         ffi/unsafe/introspection
         "gst.rkt")

(provide caps%)

(define caps% (gst 'Caps))
