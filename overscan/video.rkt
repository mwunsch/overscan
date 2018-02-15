#lang racket/base

(require racket/class
         racket/contract
         gstreamer)

(provide (contract-out [picture-in-picture
                        (->* ()
                             ((or/c string? #f))
                             (is-a?/c bin%))]))

(define (picture-in-picture video1 video2 [name #f])
  (let ([mixer (videomixer)]
        [bin (bin%-new name)])
    (send bin add-many video1 video2 mixer)
    (send video1 link mixer)
    (send video2 link mixer)
    bin))

(define (picture-in-picture-reposition pad xpos ypos)
  (gobject-set! pad "xpos" xpos _int)
  (gobject-set! pad "ypos" ypos _int))
