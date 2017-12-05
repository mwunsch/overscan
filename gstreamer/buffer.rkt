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
                            any/c)]))

(define gst-sample (gst 'Sample))

(define gst-buffer (gst 'Buffer))

(define gst-buffer-flags (gst 'BufferFlags))

(define (sample? v)
  (is-gtype? v gst-sample))

(define (buffer? v)
  (is-gtype? v gst-buffer))

(define (sample-buffer sample)
  (gobject-send sample 'get_buffer))

(define (sample-caps sample)
  (gobject-send sample 'get_caps))

(define (buffer-size buffer)
  (gobject-send buffer 'get_size))

(define (buffer-flags buffer)
  (gobject-send buffer 'get_flags))
