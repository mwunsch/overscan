#lang racket/base

(require ffi/unsafe/introspection
         racket/contract
         racket/place
         "gst.rkt")

(provide (contract-out [make-bus-channel
                        (->* ((is-a?/c gst-bus))
                             ((listof symbol?)
                              #:timeout exact-nonnegative-integer?)
                             evt?)]))

(define gst-bus (gst 'Bus))

(define gst-message (gst 'Message))

(define clock-time-none ((gst 'CLOCK_TIME_NONE)))

(define (make-bus-channel bus [filters '(any)]
                          #:timeout [timeout clock-time-none])
  (define bus-pipe
    (place chan
           (let*-values ([(bus-ptr timeout filters)
                          (apply values (place-channel-get chan))]
                         [(bus) (gobject-cast bus-ptr gst-bus)])
             (let loop ()
               (define msg
                 (send bus timed-pop-filtered timeout filters))
               (define msg-type (get-field type msg))
               (place-channel-put chan (and msg
                                            (gtype-instance-pointer msg)))
               (if (or (memq 'eos msg-type) (memq 'error msg-type))
                   (exit 0)
                   (loop))))))
  (place-channel-put bus-pipe (list (gtype-instance-pointer bus)
                                    timeout
                                    filters))
  (wrap-evt bus-pipe (lambda (ptr) (and ptr
                                   (gstruct-cast ptr gst-message)))))
