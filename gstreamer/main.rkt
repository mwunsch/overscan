#lang racket/base

(require ffi/unsafe/introspection)

(provide gst
         element-factory)

(define gst (introspection 'Gst))

(if ((gst 'init_check) 0 #f)
    (displayln ((gst 'version_string)))
    (error "Could not load Gstreamer"))

(define element-factory (gst 'ElementFactory))
