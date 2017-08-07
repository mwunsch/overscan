#lang racket/base

(require gstreamer
         ffi/unsafe/introspection)

(provide twitch-sink
         twitch-stream-key)

(define twitch-stream-key (make-parameter (getenv "TWITCH_STREAM_KEY")))

(define (twitch-sink #:test [bandwidth-test #f])
  (let* ([stream-key (twitch-stream-key)]
         [rtmp (element-factory% 'make "rtmpsink" "sink:rtmp:twitch")]
         [location (format "rtmp://live-jfk.twitch.tv/app/~a~a live=1"
                           stream-key
                           (if bandwidth-test "?bandwidthtest=true" ""))])
    (unless stream-key
      (error "no TWITCH_STREAM_KEY in env"))
    (gobject-set! rtmp "location" location)
    rtmp))
