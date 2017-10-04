#lang racket/base

(require (except-in ffi/unsafe/introspection
                    send get-field set-field! field-bound?)
         racket/class
         racket/contract
         "gst.rkt"
         "element.rkt"
         "bin.rkt"
         "bus.rkt")

(provide (contract-out [pipeline%
                        (and/c (subclass?/c bin%)
                               (class/c
                                [get-bus
                                 (->m gst-bus?)]))]))

(define pipeline-mixin
  (make-gobject-delegate get-bus))

(define pipeline%
  (class (pipeline-mixin bin%)
    (super-new)
    (inherit-field pointer)))
