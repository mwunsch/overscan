#lang racket/base

(require ffi/unsafe/introspection
         racket/contract
         "private/core.rkt"
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
                        (-> context? gst-structure?)]
                       [make-context
                        (->* (string? string? any/c)
                             (boolean?
                              #:type gtype?)
                             context?)]
                       [context-ref
                        (-> context? string?
                            (or/c any/c false/c))]))

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

(define (make-context context-type key value [persistent? #f]
                      #:type [type (if (gobject? value)
                                       (gobject-gtype value)
                                       0)])
  (let* ([context (gst-context 'new context-type persistent?)]
         [structure (context-writable-structure context)])
    (gst-structure-set! structure key value)
    context))

(define (context-ref context key)
  (let* ([structure (context-structure context)])
    (gst-structure-ref structure key)))
