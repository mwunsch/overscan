#lang racket/base

(require (rename-in ffi/unsafe [-> ~>])
         ffi/vector
         ffi/unsafe/introspection
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
                       [_map-info
                        ctype?]
                       [_map-info-pointer
                        ctype?]
                       [map-info?
                        (-> any/c boolean?)]
                       [map-info-memory
                        (-> map-info? memory?)]
                       [map-info-size
                        (-> map-info? exact-nonnegative-integer?)]
                       [map-info-maxsize
                        (-> map-info? exact-nonnegative-integer?)]
                       [map-info-data
                        (-> map-info? bytes?)]
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
                            (or/c map-info? false/c))]
                       [buffer-unmap!
                        (-> buffer?
                            map-info?
                            void?)]))

(define (sample? v)
  (is-gtype? v gst-sample))

(define (buffer? v)
  (is-gtype? v gst-buffer))

(define (memory? v)
  (is-gtype? v gst-memory))

(define (memory-sizes mem)
  (gobject-send mem 'get_sizes))

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

(define-cstruct _map-info ([memory (_gi-struct gst-memory)]
                           [flags (_gi-enum gst-map-flags)]
                           [data-pointer _pointer]
                           [size _size]
                           [maxsize _size]))

(define (map-info-data info)
  (let* ([data (map-info-data-pointer info)]
         [size (map-info-size info)]
         [ctype (_array _uint8 size)]
         [byte-array (ptr-ref data ctype)])
    (for/fold ([pixels (make-bytes size)])
              ([val (in-array byte-array)]
               [i (in-naturals)])
      (bytes-set! pixels i val)
      pixels)))

(define-gst buffer-map
  (_fun (_gi-struct gst-buffer)
        [info : (_ptr o _map-info)]
        (_gi-enum gst-map-flags)
        ~> [success? : _bool]
        ~> (and success?
                info))
  #:c-id gst_buffer_map)

(define-gst buffer-unmap!
  (_fun (_gi-struct gst-buffer)
        _map-info-pointer
        ~> _void)
  #:c-id gst_buffer_unmap)
