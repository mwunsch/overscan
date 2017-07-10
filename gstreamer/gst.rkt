#lang racket/base

(require ffi/unsafe/introspection)

(provide gst)

(define gst (introspection 'Gst))
