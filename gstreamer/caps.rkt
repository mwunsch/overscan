#lang racket/base

(require ffi/unsafe
         ffi/unsafe/introspection
         "gst.rkt")

(provide caps%
         caps-from-string
         capsfilter
         video/x-raw)

(define caps% (gst 'Caps))

(define (caps-from-string cap-string)
  (caps% 'from_string cap-string))

(define (capsfilter cap-string)
  (gobject-with-properties (element-factory% 'make "capsfilter" #f)
                           (hash 'caps (caps-from-string cap-string))))

(define (video/x-raw caps)
  (capsfilter (string-append "video/x-raw," caps)))
