#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         "private/core.rkt"
         gstreamer/caps)

(provide (contract-out [sample?
                        (-> any/c boolean?)]
                       [buffer?
                        (-> any/c boolean?)]
                       [memory?
                        (-> any/c boolean?)]
                       [map-flags?
                        flat-contract?]
                       [map-info?
                        (-> any/c boolean?)]
                       [map-info-memory
                        (-> map-info? memory?)]
                       [sample-buffer
                        (-> sample?
                            (or/c buffer? false/c))]
                       [sample-caps
                        (-> sample?
                            (or/c caps? false/c))]
                       [buffer-size
                        (-> buffer?
                            exact-nonnegative-integer?)]
                       [buffer-flags
                        (-> buffer?
                            (gi-bitmask-value/c gst-buffer-flags))]
                       [buffer-n-memory
                        (-> buffer?
                            exact-nonnegative-integer?)]
                       [buffer-peek-memory
                        (-> buffer? exact-nonnegative-integer?
                            memory?)]
                       [buffer-memory
                        (-> buffer?
                            (listof memory?))]
                       [buffer-all-memory
                        (-> buffer?
                            memory?)]
                       [buffer-map
                        (-> buffer?
                            map-flags?
                            (or/c map-info? false/c))]))

(define (sample? v)
  (is-gtype? v gst-sample))

(define (buffer? v)
  (is-gtype? v gst-buffer))

(define (memory? v)
  (is-gtype? v gst-memory))

(define (memory-sizes mem)
  (gobject-send mem 'get_sizes))

(define (map-info? v)
  (is-gtype? v gst-map-info))

(define (map-info-memory info)
  (gobject-get-field 'memory info))

(define map-flags?
  (gi-bitmask-value/c gst-map-flags))

(define (sample-buffer sample)
  (gobject-send sample 'get_buffer))

(define (sample-caps sample)
  (gobject-send sample 'get_caps))

(define (buffer-size buffer)
  (gobject-send buffer 'get_size))

(define (buffer-flags buffer)
  (gobject-send buffer 'get_flags))

(define (buffer-n-memory buffer)
  (gobject-send buffer 'n_memory))

(define (buffer-peek-memory buffer idx)
  (gobject-send buffer 'peek_memory idx))

(define (buffer-memory buffer)
  (for/list ([idx (in-range (buffer-n-memory buffer))])
    (buffer-peek-memory buffer idx)))

(define (buffer-all-memory buffer)
  (gobject-send buffer 'get_all_memory))

(define (buffer-map buffer flags)
  (let-values ([(success? info)
                (gobject-send buffer 'map flags)])
    (and success?
         info)))
