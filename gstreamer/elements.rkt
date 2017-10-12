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
                             (is-a?/c element%))]))

(define (capsfilter caps [name #f])
  (gobject-with-properties (element-factory%-make "capsfilter" name)
                           (hash 'caps caps)))
