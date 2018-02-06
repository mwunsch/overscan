#lang racket/base

(require racket/class
         racket/contract
         gstreamer)

(provide (contract-out [make-video-mixer
                        (->* ()
                             ((or/c string? #f))
                             (element/c "videomixer"))]))

(define (make-video-mixer [name #f])
  (element-factory%-make "videomixer" name))
