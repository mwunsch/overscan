#lang racket/base

(require (except-in ffi/unsafe/introspection
                    send get-field set-field! field-bound?)
         racket/class
         racket/contract
         racket/place
         "gst.rkt")

(provide (contract-out [make-bus-channel
                        (->* ((gobject/c gst-bus))
                             ((listof symbol?)
                              #:timeout exact-nonnegative-integer?)
                             (evt/c (or/c message?
                                          false/c
                                          evt?)))]
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
                         poll)]
                       [message?
                        (-> any/c boolean?)]
                       [message-type
                        (-> message? (gi-bitmask-value/c gst-message-type))]
                       [message-src
                        (-> message? (is-a?/c gst-object%))]
                       [message-seqnum
                        (-> message? exact-integer?)]))

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

(define gst-message-type (gst 'MessageType))

(define (message? v)
  (is-gtype? v gst-message))

(define (message-type msg)
  (gobject-get-field 'type msg))

(define (message-seqnum msg)
  (gobject-get-field 'seqnum msg))

(define (message-src msg)
  (new gst-object% [pointer (gobject-get-field 'src msg)]))

(define clock-time-none ((gst 'CLOCK_TIME_NONE)))

(define (make-bus-channel bus [filters '(any)]
                          #:timeout [timeout clock-time-none])
  (define bus-pipe
    (place chan
           (let*-values ([(bus-ptr timeout filter)
                          (apply values (place-channel-get chan))]
                         [(bus-obj) (gobject-cast bus-ptr gst-bus)])
             (let loop ()
               (define msg
                 (gobject-send bus-obj 'timed_pop_filtered timeout filter))
               (place-channel-put chan (and msg
                                            (gtype-instance-pointer msg)))

               (when (and msg
                          (let ([msg-type (message-type msg)])
                            (or (memq 'eos msg-type) (memq 'error msg-type))))
                 (exit 0))
               (loop)))))
  (place-channel-put bus-pipe (list (gtype-instance-pointer (gobject-ptr bus))
                                    timeout
                                    filters))
  (choice-evt (wrap-evt bus-pipe
                        (lambda (ptr) (and ptr (gstruct-cast ptr gst-message))))
              (place-dead-evt bus-pipe)))
