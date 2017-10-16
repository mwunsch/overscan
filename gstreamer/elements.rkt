#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         "gst.rkt"
         "caps.rkt"
         "element.rkt"
         "factories.rkt")

(provide (contract-out [capsfilter
                        (->* (caps?)
                             ((or/c string? false/c))
                             (is-a?/c element%))]
                       [rtmpsink
                        (->* (string?)
                             ((or/c string? false/c))
                             sink?)]))

(define (capsfilter caps [name #f])
  (gobject-with-properties (element-factory%-make "capsfilter" name)
                           (hash 'caps caps)))

(define (rtmpsink location [name #f])
  (gobject-with-properties (element-factory%-make "rtmpsink" name)
                           (hash 'location location)))
