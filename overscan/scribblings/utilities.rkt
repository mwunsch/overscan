#lang racket/base

(require scribble/base
         scribble/core
         scribble/html-properties)

(provide video)

(define (video path)
  (elem (make-source path)
   #:style (style #f
                  (list (alt-tag "video")
                        (attributes '((muted . "muted")
                                      (autoplay . "autoplay")
                                      (loop . "loop")
                                      (playsinline . "playsinline")))))))

(define (make-source path)
  (elem
   #:style
   (style #f
          (list (alt-tag "source")
                (attributes (list (cons 'src path)
                                  (cons 'type "video/mp4")))))))
