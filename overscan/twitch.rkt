#lang racket/base

(require racket/contract
         gstreamer)

(provide (contract-out [twitch-sink
                        (->* () (#:test boolean?) sink?)]
                       [twitch-stream-key
                        (parameter/c string?)]))

(define twitch-stream-key (make-parameter (getenv "TWITCH_STREAM_KEY")))

(define (twitch-sink #:test [bandwidth-test #f])
  (define stream-key (twitch-stream-key))
  (unless stream-key
    (error "no TWITCH_STREAM_KEY in env"))

  (let ([location (format "rtmp://live-jfk.twitch.tv/app/~a~a live=1"
                          stream-key
                          (if bandwidth-test "?bandwidthtest=true" ""))])
    (make-rtmpsink location "sink:rtmp:twitch")))
