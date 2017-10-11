#lang racket/base

(require (except-in ffi/unsafe
                    ->)
         ffi/unsafe/introspection
         (only-in racket/list first last)
         racket/class
         racket/contract
         "gst.rkt"
         "caps.rkt"
         "clock.rkt"
         "bus.rkt"
         "element.rkt"
         "bin.rkt"
         "pipeline.rkt")

(provide (all-from-out "gst.rkt"
                       "caps.rkt"
                       "clock.rkt"
                       "bus.rkt"
                       "element.rkt"
                       "bin.rkt"
                       "pipeline.rkt")
         _input-selector-sync-mode
         _video-test-src-pattern
         _audio-test-src-wave
         (contract-out [element-factory%-find
                        (-> string? (or/c false/c
                                          (is-a?/c element-factory%)))]
                       [element-factory%-make
                        (->* (string?)
                             ((or/c string? false/c))
                             (or/c false/c
                                   (is-a?/c element%)))]
                       [ghost-pad%-new
                        (-> (or/c string? false/c) (is-a?/c pad%)
                            (or/c (is-a?/c ghost-pad%)
                                  false/c))]
                       [ghost-pad%-new-no-target
                        (-> (or/c string? false/c) (gi-enum-value/c pad-direction)
                            (or/c (is-a?/c ghost-pad%)
                                  false/c))]
                       [capsfilter
                        (->* (caps?)
                             ((or/c string? false/c))
                             (is-a?/c element%))]
                       [bin%-new
                        (->* ()
                             ((or/c string? false/c))
                             (is-a?/c bin%))]
                       [bin%-compose
                        (-> (or/c string? false/c)
                            (is-a?/c element%) (is-a?/c element%) ...
                            (or/c (is-a?/c bin%) false/c))]
                       [pipeline%-new
                        (->* ()
                             ((or/c string? false/c))
                             (is-a?/c pipeline%))]
                       [pipeline%-compose
                        (-> (or/c string? false/c)
                            (is-a?/c element%) ...
                            (or/c (is-a?/c pipeline%) false/c))]
                       [obtain-system-clock
                        (-> (is-a?/c clock%))]))

(define gst-element-factory (gst 'ElementFactory))

(define (element-factory%-find name)
  (let ([factory (gst-element-factory 'find name)])
    (and factory
         (new element-factory% [pointer factory]))))

(define (element-factory%-make factory-name [name #f])
  (let ([el (gst-element-factory 'make factory-name name)])
    (and el
         (new element% [pointer el]))))

(define gst-ghost-pad (gst 'GhostPad))

(define (ghost-pad%-new name target)
  (let ([ghost (gst-ghost-pad 'new name target)])
    (and ghost
         (new ghost-pad% [pointer ghost]))))

(define (ghost-pad%-new-no-target name dir)
  (let ([ghost (gst-ghost-pad 'new_no_target name dir)])
    (and ghost
         (new ghost-pad% [pointer ghost]))))

(define (capsfilter caps [name #f])
  (gobject-with-properties (element-factory%-make "capsfilter" name)
                           (hash 'caps caps)))

(define gst-bin (gst 'Bin))

(define (bin%-new [name #f])
  (new bin% [pointer (gst-bin 'new name)]))

(define (bin%-compose name el . els)
  (let* ([bin (bin%-new name)]
         [sink el]
         [source (if (null? els) el (last els))])
    (and (send/apply bin add-many el els)
         (when (pair? els)
           (send/apply el link-many els))
         (let ([sink-pad (send sink get-static-pad "sink")])
           (if sink-pad
               (send bin add-pad (ghost-pad%-new "sink" sink-pad))
             #t))
         (let ([source-pad (send source get-static-pad "src")])
           (if source-pad
               (send bin add-pad (ghost-pad%-new "src" source-pad))
             #t))
         bin)))

(define gst-pipeline (gst 'Pipeline))

(define (pipeline%-new [name #f])
  (new pipeline% [pointer (gst-pipeline 'new name)]))

(define (pipeline%-compose name . els)
  (let* ([pl (pipeline%-new name)]
         [bin (apply bin%-compose #f els)])
    (and (send pl add bin)
         pl)))

(define (obtain-system-clock)
  (new clock% [pointer ((gst 'SystemClock) 'obtain)]))

(define event% (gst 'Event))

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
