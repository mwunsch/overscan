#lang racket/base

(require (rename-in ffi/unsafe [-> ~>])
         ffi/unsafe/define
         ffi/unsafe/introspection
         racket/contract
         racket/class)

(provide (contract-out [gst
                        gi-repository?]
                       [libgstreamer
                        ffi-lib?]
                       [gst-bin
                        gi-object?]
                       [gst-bus
                        gi-object?]
                       [gst-buffer
                        gi-struct?]
                       [gst-buffer-flags
                        gi-bitmask?]
                       [gst-buffering-mode
                        gi-enum?]
                       [gst-caps
                        gi-struct?]
                       [gst-clock
                        gi-object?]
                       [gst-context
                        gi-struct?]
                       [gst-element
                        gi-object?]
                       [gst-element-factory
                        gi-object?]
                       [gst-event
                        gi-struct?]
                       [gst-event-type
                        gi-enum?]
                       [gst-format
                        gi-enum?]
                       [gst-ghost-pad
                        gi-object?]
                       [gst-map-flags
                        gi-bitmask?]
                       [gst-map-info
                        gi-struct?]
                       [gst-memory
                        gi-struct?]
                       [gst-message
                        gi-struct?]
                       [gst-message-type
                        gi-bitmask?]
                       [gst-pad
                        gi-object?]
                       [gst-pad-direction
                        gi-enum?]
                       [gst-pad-link-return
                        gi-enum?]
                       [gst-pad-presence
                        gi-enum?]
                       [gst-pad-template
                        gi-object?]
                       [gst-pipeline
                        gi-object?]
                       [gst-sample
                        gi-struct?]
                       [gst-state
                        gi-enum?]
                       [gst-state-change-return
                        gi-enum?]
                       [gst-stream-status-type
                        gi-enum?]
                       [gst-structure
                        gi-struct?]
                       [gst-tag-list
                        gi-struct?]
                       [mini-object?
                        (-> any/c
                            boolean?)]
                       [gst-mini-object
                        gi-struct?]
                       [_mini-object
                        ctype?]
                       [mini-object-ref
                        (-> mini-object? mini-object?)]
                       [mini-object-unref
                        (-> mini-object? void?)]
                       [mini-object-type
                        (-> mini-object? gtype?)]
                       [mini-object-refcount
                        (-> mini-object? exact-nonnegative-integer?)])
         define-gst)

(define gst
  (introspection 'Gst))

(define libgstreamer
  (gi-repository->ffi-lib gst))

(define-ffi-definer define-gst libgstreamer)

(define gst-bin
  (gst 'Bin))

(define gst-bus
  (gst 'Bus))

(define gst-buffer
  (gst 'Buffer))

(define gst-buffer-flags
  (gst 'BufferFlags))

(define gst-buffering-mode
  (gst 'BufferingMode))

(define gst-caps
  (gst 'Caps))

(define gst-clock
  (gst 'Clock))

(define gst-context
  (gst 'Context))

(define gst-element
  (gst 'Element))

(define gst-element-factory
  (gst 'ElementFactory))

(define gst-event
  (gst 'Event))

(define gst-event-type
  (gst 'EventType))

(define gst-format
  (gst 'Format))

(define gst-ghost-pad
  (gst 'GhostPad))

(define gst-map-flags
  (gst 'MapFlags))

(define gst-map-info
  (gst 'MapInfo))

(define gst-memory
  (gst 'Memory))

(define gst-message
  (gst 'Message))

(define gst-message-type
  (gst 'MessageType))

(define gst-pad
  (gst 'Pad))

(define gst-pad-direction
  (gst 'PadDirection))

(define gst-pad-link-return
  (gst 'PadLinkReturn))

(define gst-pad-presence
  (gst 'PadPresence))

(define gst-pad-template
  (gst 'PadTemplate))

(define gst-pipeline
  (gst 'Pipeline))

(define gst-sample
  (gst 'Sample))

(define gst-state
  (gst 'State))

(define gst-state-change-return
  (gst 'StateChangeReturn))

(define gst-stream-status-type
  (gst 'StreamStatusType))

(define gst-structure
  (gst 'Structure))

(define gst-tag-list
  (gst 'TagList))

(define gst-mini-object
  (gst 'MiniObject))

(define (mini-object? v)
  (is-gtype? v gst-mini-object))

(define _mini-object
  (_gi-struct gst-mini-object))

(define-gst mini-object-ref (_fun _mini-object ~> _mini-object)
  #:c-id gst_mini_object_ref)

(define-gst mini-object-unref (_fun _mini-object ~> _void)
  #:c-id gst_mini_object_unref)

(define (mini-object-type object)
  (gobject-get-field 'type object))

(define (mini-object-refcount object)
  (gobject-get-field 'refcount object))
