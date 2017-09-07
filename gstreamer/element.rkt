#lang racket/base

(require ffi/unsafe/introspection
         "gst.rkt")

(provide element%
         element-factory%)

(define element-factory% (gst 'ElementFactory))

(define element% (gst 'Element))

(define (sink? el)
  (and (zero? (get-field numsrcpads el))
       (positive? (get-field numsinkpads el))))

(define (src? el)
  (not (sink? el)))
