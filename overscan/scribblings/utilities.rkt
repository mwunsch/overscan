#lang racket/base

(require scribble/base
         scribble/core
         scribble/html-properties
         racket/path
         racket/runtime-path
         (only-in net/url relative-path->relative-url-string))

(provide video)

(define-runtime-path scribblings ".")

(define (video path)
  (elem (source path)
   #:style (style #f
                  (list (alt-tag "video")
                        (attributes '((muted . "muted")
                                      (autoplay . "autoplay")
                                      (loop . "loop")
                                      (playsinline . "playsinline")
                                      (style . "width: 100%;")))))))

(define (source path)
  (elem
   #:style
   (style #f
          (list (alt-tag "source")
                (install-resource (path->complete-path (build-path scribblings path)))
                (attributes (list (cons 'src (relative-path->relative-url-string
                                              (file-name-from-path path)))
                                  (cons 'type "video/mp4")))))))
