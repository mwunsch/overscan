#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         gstreamer/gst
         gstreamer/caps)

(provide (contract-out [sample?
                        (-> any/c boolean?)]
                       [buffer?
                        (-> any/c boolean?)]
                       [memory?
                        (-> any/c boolean?)]
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
                            any/c)]
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
                       [buffer-ref!
                        (-> buffer? mini-object?)]
                       [buffer-unref!
                        (-> buffer? void?)]))

(define gst-sample (gst 'Sample))

(define gst-buffer (gst 'Buffer))

(define gst-memory (gst 'Memory))

(define gst-buffer-flags (gst 'BufferFlags))

(define (sample? v)
  (is-gtype? v gst-sample))

(define (buffer? v)
  (is-gtype? v gst-buffer))

(define (memory? v)
  (is-gtype? v gst-memory))

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

(define (buffer-ref! buffer)
  (mini-object-ref! (gstruct-cast buffer gst-mini-object)))

(define (buffer-unref! buffer)
  (mini-object-unref! (gstruct-cast buffer gst-mini-object)))
