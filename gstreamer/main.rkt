#lang racket/base

(require ffi/unsafe
         ffi/unsafe/introspection
         (only-in racket/list first last)
         "gst.rkt"
         "bus.rkt"
         "caps.rkt"
         "element.rkt")

(provide (all-from-out "gst.rkt"
                       "bus.rkt"
                       "caps.rkt"
                       "element.rkt")
         pipeline%
         pad%
         bin%
         event%
         bin-add-many
         ghost-pad%
         seconds
         element-link-many
         _input-selector-sync-mode
         _video-test-src-pattern
         _audio-test-src-wave
         gst-compose)

(define pipeline% (gst 'Pipeline))

(define pad% (gst 'Pad))

(define bin% (gst 'Bin))

(define event% (gst 'Event))

(define second ((gst 'SECOND)))

(define ghost-pad% (gst 'GhostPad))

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

(define _input-selector-sync-mode (_enum '(active-segment clock)))

(define (gst-compose name . elements)
  (let* ([bin (bin% 'new name)]
         [sink (first elements)]
         [source (last elements)])
    (and (> (length elements) 0)
         (apply bin-add-many bin elements)
         (apply element-link-many elements)
         (let ([sink-pad (send sink get-static-pad "sink")])
           (if sink-pad
               (send bin add-pad (ghost-pad% 'new "sink" sink-pad))
               #t))
         (let ([source-pad (send source get-static-pad "src")])
           (if source-pad
               (send bin add-pad (ghost-pad% 'new "src" source-pad))
               #t))
         bin)))

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
