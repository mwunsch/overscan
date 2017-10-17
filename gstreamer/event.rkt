#lang racket/base

(require ffi/unsafe/introspection
         racket/contract
         gstreamer/gst)

(provide (contract-out [event?
                        (-> any/c boolean?)]
                       [event-type
                        (-> event? (gi-enum-value/c gst-event-type))]
                       [event-seqnum
                        (-> event? exact-integer?)]
                       [make-eos-event
                        (-> event?)]))

(define gst-event (gst 'Event))

(define gst-event-type (gst 'EventType))

(define (event? v)
  (is-gtype? v gst-event))

(define (event-type ev)
  (gobject-get-field 'type ev))

(define (event-seqnum ev)
  (gobject-send ev 'get_seqnum))

(define (make-eos-event)
  (gst-event 'new_eos))
