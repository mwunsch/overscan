#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         (only-in racket/function thunk)
         gstreamer/gst
         gstreamer/clock
         gstreamer/caps
         gstreamer/event
         gstreamer/element
         gstreamer/factories)

(provide (contract-out [appsink%
                        (subclass?/c element%)]
                       [appsink
                        (->* ()
                             ((or/c string? false/c)
                              (subclass?/c appsink%))
                             (is-a?/c appsink%))]))

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

    (define worker
      (thread (thunk
               (let loop ()
                 (let-values ([(sample) (gobject-send appsink-ptr 'pull_sample)]
                              [(statechange current pending) (get-state)])
                   (if (eq? current 'playing)
                       (if (eos?)
                           (begin
                             (on-eos)
                             (kill-thread (current-thread)))
                           (on-sample sample))
                       (sleep 1/30))    ; poll 30 fps while waiting for state change
                   (loop))))))

    (define/public-final (eos?)
      (gobject-send appsink-ptr 'is_eos))
    (define/public-final (dropping?)
      (gobject-send appsink-ptr 'get_drop))
    (define/public-final (get-max-buffers)
      (gobject-send appsink-ptr 'get_max_buffers))
    (define/public-final (get-eos-evt)
      (thread-dead-evt worker))
    (define/pubment (on-sample sample)
      (inner (println (format "got a sample ~a" sample))
             on-sample sample))
    (define/pubment (on-eos)
      (inner (println "!!! eos !!!")
             on-eos))))

(define (appsink [name #f] [class% appsink%])
  (let* ([obj (element-factory%-make "appsink" name)]
         [ptr (get-field pointer obj)])
    (new class% [pointer ptr])))
