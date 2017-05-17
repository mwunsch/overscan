#lang racket/base

(require ffi/unsafe
         ffi/unsafe/introspection
         "gst.rkt"
         "bus.rkt")

(provide (all-from-out "gst.rkt"
                       "bus.rkt")
         element-factory%
         element%
         pipeline%
         bin%
         caps%
         event%
         bin-add-many
         seconds
         element-link-many)

(define element-factory% (gst 'ElementFactory))

(define pipeline% (gst 'Pipeline))

(define bin% (gst 'Bin))

(define caps% (gst 'Caps))

(define element% (gst 'Element))

(define event% (gst 'Event))

(define second ((gst 'SECOND)))

(define (seconds num)
  (* num second))

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
