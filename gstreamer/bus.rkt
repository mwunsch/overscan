#lang racket/base

(require (except-in ffi/unsafe/introspection
                    send get-field set-field! field-bound?)
         racket/class
         racket/contract
         racket/place
         "gst.rkt")

(provide (contract-out [make-bus-channel
                        (->* ((is-a?/c bus%))
                             ((listof symbol?)
                              #:timeout exact-nonnegative-integer?)
                             evt?)]
                       [bus%
                        (class/c
                         post
                         have-pending?
                         peek
                         pop
                         pop-filtered
                         timed-pop
                         timed-pop-filtered
                         disable-sync-message-emission!
                         enable-sync-message-emission!
                         poll)]))

(define gst-bus (gst 'Bus))

(define bus-mixin
  (make-gobject-delegate post
                         [have-pending? 'have_pending]
                         peek
                         pop
                         pop-filtered
                         timed-pop
                         timed-pop-filtered
                         [disable-sync-message-emission!
                          'disable_sync_message_emission]
                         [enable-sync-message-emission!
                          'enable_sync_message_emission]
                         poll))

(define bus%
  (class (bus-mixin gst-object%)
    (super-new)
    (inherit-field pointer)))

(define gst-message (gst 'Message))

(define clock-time-none ((gst 'CLOCK_TIME_NONE)))

(define (make-bus-channel bus [filters '(any)]
                          #:timeout [timeout clock-time-none])
  (define bus-pipe
    (place chan
           (let*-values ([(bus-ptr timeout filter)
                          (apply values (place-channel-get chan))]
                         [(bus-obj) (new bus% [pointer (gobject-cast bus-ptr gst-bus)])])
             (let loop ()
               (define msg
                 (send bus-obj timed-pop-filtered timeout filter))
               (define msg-type (gobject-get-field 'type msg))
               (place-channel-put chan (and msg
                                            (gtype-instance-pointer msg)))
               (if (or (memq 'eos msg-type) (memq 'error msg-type))
                   (exit 0)
                   (loop))))))
  (place-channel-put bus-pipe (list (gtype-instance-pointer (get-field pointer bus))
                                    timeout
                                    filters))
  (wrap-evt bus-pipe (lambda (ptr) (and ptr
                                   (gstruct-cast ptr gst-message)))))
