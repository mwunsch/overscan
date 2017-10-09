#lang racket/base

(require (except-in ffi/unsafe/introspection
                    send get-field set-field! field-bound?)
         racket/class
         racket/contract
         "gst.rkt"
         "clock.rkt"
         "element.rkt"
         "bin.rkt"
         "bus.rkt")

(provide (contract-out [pipeline%
                        (class/c
                         [get-bus
                          (->m (is-a?/c bus%))]
                         [get-pipeline-clock
                          (->m (is-a?/c clock%))]
                         [get-latency
                          (->m clock-time?)])]))

(define pipeline-mixin
  (make-gobject-delegate get-bus
                         get-pipeline-clock
                         get-latency))

(define pipeline%
  (class (pipeline-mixin bin%)
    (super-new)
    (inherit-field pointer)
    (define/override (get-bus)
      (new bus% [pointer (super get-bus)]))
    (define/override (get-pipeline-clock)
      (new clock% [pointer (super get-pipeline-clock)]))))
