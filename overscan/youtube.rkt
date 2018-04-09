#lang racket/base

(require racket/contract
         gstreamer)

(provide (contract-out [youtube-sink
                        (-> string?
                            sink?)]))

(define (youtube-sink location)
  (rtmpsink location "sink:rtmp:youtube"))
