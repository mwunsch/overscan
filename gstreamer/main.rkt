#lang racket/base

(require (except-in ffi/unsafe
                    ->)
         ffi/unsafe/introspection
         racket/class
         racket/contract
         "gst.rkt"
         "caps.rkt"
         "clock.rkt"
         "bus.rkt"
         "event.rkt"
         "element.rkt"
         "bin.rkt"
         "pipeline.rkt"
         "factories.rkt"
         "elements.rkt")

(provide (all-from-out "gst.rkt"
                       "caps.rkt"
                       "clock.rkt"
                       "bus.rkt"
                       "event.rkt"
                       "element.rkt"
                       "bin.rkt"
                       "pipeline.rkt"
                       "factories.rkt"
                       "elements.rkt")
         (contract-out [obtain-system-clock
                        (-> (is-a?/c clock%))]))

(define (obtain-system-clock)
  (new clock% [pointer ((gst 'SystemClock) 'obtain)]))
