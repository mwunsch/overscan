#lang racket/base

(require ffi/unsafe
         ffi/unsafe/introspection
         "gst.rkt"
         "bus.rkt")

(provide (all-from-out "gst.rkt"
                       "bus.rkt")
         element-factory%
         pipeline%
         caps%
         bin-add-many
         element-link-many)

(define element-factory% (gst 'ElementFactory))

(define pipeline% (gst 'Pipeline))

(define caps% (gst 'Caps))

(define element% (gst 'Element))

(define (bin-add-many bin . elements)
  (for/and ([element elements])
    (send bin add element)))

(define (element-link-many . elements)
  (let link ([head (car elements)]
             [tail (cdr elements)])
    (if (pair? tail)
        (and (send head link (car tail))
             (link (car tail) (cdr tail)))
        #t)))
