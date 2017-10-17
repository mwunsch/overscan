#lang racket/base

(require (except-in ffi/unsafe
                    ->)
         ffi/unsafe/introspection
         racket/class
         racket/contract
         gstreamer/gst
         gstreamer/caps
         gstreamer/clock
         gstreamer/bus
         gstreamer/event
         gstreamer/element
         gstreamer/bin
         gstreamer/pipeline
         gstreamer/factories
         gstreamer/elements)

(provide (all-from-out gstreamer/gst
                       gstreamer/caps
                       gstreamer/clock
                       gstreamer/bus
                       gstreamer/event
                       gstreamer/element
                       gstreamer/bin
                       gstreamer/pipeline
                       gstreamer/factories
                       gstreamer/elements)
         (contract-out [obtain-system-clock
                        (-> (is-a?/c clock%))]))

(define (obtain-system-clock)
  (new clock% [pointer ((gst 'SystemClock) 'obtain)]))
