#lang racket/base

(require racket/class
         racket/contract
         racket/draw
         (only-in racket/string string-split)
         ffi/unsafe/introspection
         gstreamer
         gstreamer/draw)

(provide (contract-out [make-drawable
                        (->* ((is-a?/c element%))
                             (#:width exact-nonnegative-integer?
                              #:height exact-nonnegative-integer?)
                             (values (or/c (is-a?/c bin%) false/c)
                                     (is-a?/c bitmap-dc%)))]))

(define (make-drawable element
                       #:width [width 1280]
                       #:height [height 720])
  (let* ([el-name (send element get-name)]
         [target (make-bitmap width height)]
         [dc (new bitmap-dc% [bitmap target])]
         [queue (element-factory%-make "queue")]
         [overlay (make-cairo-overlay dc
                                      (format "~a:draw-overlay" el-name))])
    (gobject-set! queue "leaky" 'downstream '(no upstream downstream))
    (values (bin%-compose #f
                          element
                          (element-factory%-make "videoconvert")
                          queue
                          overlay)
            dc)))
