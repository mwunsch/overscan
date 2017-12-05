#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         racket/async-channel
         (only-in racket/function thunk const)
         gstreamer/gst
         gstreamer/clock
         gstreamer/caps
         gstreamer/buffer
         gstreamer/event
         gstreamer/element
         gstreamer/factories)

(provide (contract-out [appsink%
                        (and/c (subclass?/c element%)
                               appsink%/c)]
                       [make-appsink
                        (->* ()
                             ((or/c string? false/c)
                              (subclass?/c appsink%))
                             (instanceof/c appsink%/c))]))

(define gst-app
  (introspection 'GstApp))

(define gst-appsink
  (gst-app 'AppSink))

(define appsink%
  (class* element% ()
    (super-new)
    (inherit-field pointer)
    (inherit get-state)

    (define appsink-ptr
      (gobject-cast pointer gst-appsink))

    (define eos-channel
      (make-async-channel))

    (define worker
      (thread (thunk
               (let loop ()
                 (if (async-channel-try-get eos-channel)
                     (on-eos)
                     (let ([sample (gobject-send appsink-ptr 'pull_sample)])
                       (if sample
                           (on-sample sample)
                           (sleep 1/30))    ; poll 30 fps while waiting for state change
                       (loop)))))))

    (connect appsink-ptr 'eos void
             #:channel eos-channel)

    (define/public-final (eos?)
      (gobject-send appsink-ptr 'is_eos))
    (define/public-final (dropping?)
      (gobject-send appsink-ptr 'get_drop))
    (define/public-final (get-max-buffers)
      (gobject-send appsink-ptr 'get_max_buffers))
    (define/public-final (get-eos-evt)
      (thread-dead-evt worker))
    (define/pubment (on-sample sample)
      (inner void
             on-sample sample))
    (define/pubment (on-eos)
      (inner void
             on-eos))))

(define appsink%/c
  (class/c
   [eos?
    (->m boolean?)]
   [dropping?
    (->m boolean?)]
   [get-max-buffers
    (->m exact-nonnegative-integer?)]
   [get-eos-evt
    (->m evt?)]
   (inner [on-sample
           (->m sample?
                any)])
   (inner [on-eos
           (->m any)])))

(define (make-appsink [name #f] [class% appsink%])
  (let* ([obj (element-factory%-make "appsink" name)]
         [ptr (get-field pointer obj)])
    (new class% [pointer ptr])))
