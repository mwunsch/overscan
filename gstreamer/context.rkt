#lang racket/base

(require ffi/unsafe/introspection
         racket/contract
         gstreamer/gst
         "private/structure.rkt")

(provide (contract-out [context?
                        (-> any/c boolean?)]
                       [context-type
                        (-> context? string?)]
                       [context-has-type?
                        (-> context? string? boolean?)]
                       [context-persistent?
                        (-> context? boolean?)]
                       [context-structure
                        (-> context? gst-structure?)]
                       [context-writable-structure
                        (-> context? gst-structure?)]))

(define gst-context (gst 'Context))

(define (context? v)
  (is-gtype? v gst-context))

(define (context-type context)
  (gobject-send context 'get_context_type))

(define (context-has-type? context context-type)
  (gobject-send context 'has_context_type context-type))

(define (context-persistent? context)
  (gobject-send context 'is_persistent))

(define (context-structure context)
  (gobject-send context 'get_structure))

(define (context-writable-structure context)
  (gobject-send context 'writable_structure))
