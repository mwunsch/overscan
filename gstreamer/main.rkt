#lang racket/base

(require ffi/unsafe/introspection
         racket/class)

(gir/require 'Gst (init_check
                   version_string
                   ElementFactory))

(provide gst
         element-factory)

(define gst (introspection 'Gst))

(if (init-check 0 #f)
    (displayln (version-string))
    (error "Could not load Gstreamer"))
