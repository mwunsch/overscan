#lang racket/base

(require ffi/unsafe/introspection)

(provide gst
         element-factory)

(define gst (introspection 'Gst))

(if ((gst 'init_check) 0 #f)
    (displayln ((gst 'version_string)))
    (error "Could not load Gstreamer"))

(define element-factory (gst 'ElementFactory))

(define pipeline (gst 'Pipeline))

(define bin (gst 'Bin))

(define my-pipeline (pipeline 'new "my-pipeline"))
(define source (element-factory 'make "fakesrc" "source"))
(define filter (element-factory 'make "identity" "filter"))
(define sink (element-factory 'make "fakesink" "sink"))

(define (pipeline-add-many pipeline . elements)
  (for/and ([element elements])
    (bin 'add pipeline element)))
