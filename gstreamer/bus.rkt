#lang racket/base

(require ffi/unsafe/introspection
         racket/contract
         racket/place
         "gst.rkt")

(provide (contract-out [make-bus-channel
                        (->* ((is-a?/c bus%))
                             ((listof symbol?)
                              #:timeout exact-nonnegative-integer?)
                             evt?)]))

(define bus% (gst 'Bus))

(define message% (gst 'Message))

(define clock-time-none ((gst 'CLOCK_TIME_NONE)))

(define (make-bus-channel bus [filters '(any)]
                          #:timeout [timeout clock-time-none])
  (define bus-pipe
    (place chan
           (let*-values ([(bus-ptr timeout filters)
                          (apply values (place-channel-get chan))]
                         [(bus) (gobject-cast bus-ptr bus%)])
             (let loop ()
               (define msg
                 (send bus timed-pop-filtered timeout filters))
               (place-channel-put chan (and msg
                                            (gtype-instance-pointer msg)))
               (loop)))))
  (place-channel-put bus-pipe (list (gtype-instance-pointer bus)
                                    timeout
                                    filters))
  ;; (define bus-pipe (make-channel))
  ;; (thread
  ;;  (let loop ()
  ;;    (define msg
  ;;      (send bus timed-pop-filtered timeout filters))
  ;;    (channel-put bus-pipe (and msg
  ;;                               (gtype-instance-pointer msg)))
  ;;    (loop)))
  (wrap-evt bus-pipe (lambda (ptr) (and ptr
                                   (gstruct-cast ptr message%)))))
