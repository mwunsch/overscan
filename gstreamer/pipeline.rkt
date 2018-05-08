#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         gstreamer/gst
         gstreamer/clock
         gstreamer/bin
         gstreamer/bus)

(provide (contract-out [pipeline%
                        (class/c
                         [get-bus
                          (->m (is-a?/c bus%))]
                         [get-pipeline-clock
                          (->m (is-a?/c clock%))]
                         [use-clock
                          (->m (is-a?/c clock%)
                               void?)]
                         [get-latency
                          (->m clock-time?)])]))

(define pipeline-mixin
  (make-gobject-delegate get-bus
                         get-pipeline-clock
                         use-clock
                         get-latency))

(define pipeline%
  (class (pipeline-mixin bin%)
    (super-new)
    (inherit-field pointer)
    (define/override (get-bus)
      (new bus% [pointer (super get-bus)]))
    (define/override (get-pipeline-clock)
      (new clock% [pointer (super get-pipeline-clock)]))))
