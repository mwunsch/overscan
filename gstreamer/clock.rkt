#lang racket/base

(require (except-in ffi/unsafe/introspection
                    send get-field set-field! field-bound?)
         racket/class
         racket/contract
         "gst.rkt")

(provide (contract-out [clock%
                        (class/c
                         [get-time
                          (->m clock-time?)])]
                       [clock-time?
                        (-> any/c boolean?)]
                       [clock-time-none
                        clock-time?]
                       [time-as-seconds
                        (-> clock-time? exact-integer?)]
                       [time-as-milliseconds
                        (-> clock-time? exact-integer?)]
                       [time-as-microseconds
                        (-> clock-time? exact-integer?)]
                       [clock-diff
                        (-> clock-time? clock-time? clock-time?)]))

(define clock-mixin
  (make-gobject-delegate get-time))

(define clock%
  (class (clock-mixin gst-object%)
    (super-new)
    (inherit-field pointer)))

(define clock-time?
  exact-integer?)

(define clock-time-none
  ((gst 'CLOCK_TIME_NONE)))

(define second
  ((gst 'SECOND)))

(define nanosecond
  ((gst 'NSECOND)))

(define microsecond
  ((gst 'USECOND)))

(define (time-as-seconds t)
  (quotient t second))

(define (time-as-milliseconds t)
  (quotient t 1000000))

(define (time-as-microseconds t)
  (quotient t microsecond))

(define (clock-diff s e)
  (- e s))
