#lang racket/base

(require ffi/unsafe
         ffi/unsafe/introspection)

(provide gst)

(define gst (introspection 'Gst))

(if ((gst 'init_check) 0 #f)
    (displayln ((gst 'version_string)))
    (error "Could not load Gstreamer"))

(define pipeline ((gst 'parse_launch) "playbin uri=http://movietrailers.apple.com/movies/marvel/thor-ragnarok/thor-ragnarok-trailer-1_h720p.mov"))

;; (send pipeline set-state 'playing)

(define bus (send pipeline get-bus))
;; (define msg (send bus timed-pop-filtered ((gst 'CLOCK_TIME_NONE)) 'eos))
