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
         "factories.rkt")

(provide (all-from-out "gst.rkt"
                       "caps.rkt"
                       "clock.rkt"
                       "bus.rkt"
                       "event.rkt"
                       "element.rkt"
                       "bin.rkt"
                       "pipeline.rkt"
                       "factories.rkt")
         _input-selector-sync-mode
         _video-test-src-pattern
         _audio-test-src-wave
         (contract-out [capsfilter
                        (->* (caps?)
                             ((or/c string? false/c))
                             (is-a?/c element%))]

                       [obtain-system-clock
                        (-> (is-a?/c clock%))]))



(define (capsfilter caps [name #f])
  (gobject-with-properties (element-factory%-make "capsfilter" name)
                           (hash 'caps caps)))

(define (obtain-system-clock)
  (new clock% [pointer ((gst 'SystemClock) 'obtain)]))

(define _input-selector-sync-mode (_enum '(active-segment clock)))

(define _video-test-src-pattern (_enum '(smpte
                                         snow black white red green blue
                                         checkers1 checkers2 checkers4 checkers8
                                         circular blink smpte75 zone-plate gamut
                                         chroma-zone-plate solid ball pinwhell spokes
                                         gradient colors)))

(define _audio-test-src-wave (_enum '(sine
                                      square saw triangle silence
                                      white-noise pink-noise sine-tab
                                      ticks gaussian-noise red-noise blue-noise violet-noise)))
