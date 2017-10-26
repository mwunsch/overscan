#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         gstreamer/gst
         gstreamer/caps
         gstreamer/element
         gstreamer/factories)

(provide (contract-out [make-capsfilter
                        (->* (caps?)
                             ((or/c string? false/c))
                             (is-a?/c element%))]
                       [make-rtmpsink
                        (->* (string?)
                             ((or/c string? false/c))
                             sink?)]))

(define (make-capsfilter caps [name #f])
  (gobject-with-properties (element-factory%-make "capsfilter" name)
                           (hash 'caps caps)))

(define (make-rtmpsink location [name #f])
  (gobject-with-properties (element-factory%-make "rtmpsink" name)
                           (hash 'location location)))
